// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {CTBondingCurve} from "src/CTBondingCurve.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {CTBondingCurve} from "src/CTBondingCurve.sol";
import {CreatorTokenFactory, Attestation} from "src/CreatorTokenFactory.sol";
import {
  ITestableShowtimeVerifier,
  IShowtimeVerifier
} from "test/interfaces/ITestableShowtimeVerifier.sol";
import {MockFailingVerifier} from "test/mocks/MockFailingVerifier.sol";

contract CreatorTokenFactoryTest is Test {
  uint256 BASE_FORK_BLOCK = 4_522_844; // arbitrary as long as after verifier deployment
  CreatorTokenFactory factory;

  // The production showtime verifier contract deployed on Base mainnet
  ITestableShowtimeVerifier VERIFIER =
    ITestableShowtimeVerifier(0x481273EB2B6A21e918f6952A6c53C08691FE768F);

  // Copied from ShowtimeVerifier implementation
  //https://github.com/showtime-xyz/showtime-contracts-v2/blob/173bba71afd6b032874774f92b55d1c053cf386e/src/ShowtimeVerifier.sol#L18
  uint256 constant MAX_ATTESTATION_VALIDITY_SECONDS = 5 * 60;

  uint256 constant MAX_FEE = 2500; // Copied from Creator Token private constant

  address showtimeSigner;
  uint256 showtimeSignerKey;

  event CreatorTokenDeployed(
    CreatorToken indexed creatorToken,
    CTBondingCurve indexed bondingCurve,
    CreatorTokenFactory.DeploymentConfig config
  );

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("base"), BASE_FORK_BLOCK);
    factory = new CreatorTokenFactory(VERIFIER);

    (showtimeSigner, showtimeSignerKey) = makeAddrAndKey("showtime test signer");

    vm.prank(VERIFIER.owner());
    VERIFIER.registerSigner(showtimeSigner, 365);
  }

  function _attestationDigest(Attestation memory _attestation) public view returns (bytes32) {
    bytes memory encodedStruct = VERIFIER.encode(_attestation);
    bytes32 structHash = keccak256(abi.encodePacked(VERIFIER.REQUEST_TYPE_HASH(), encodedStruct));
    return keccak256(abi.encodePacked("\x19\x01", VERIFIER.domainSeparator(), structHash));
  }

  function _showtimeSignature(bytes32 _digest) public view returns (bytes memory _encodedSignature) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(showtimeSignerKey, _digest);
    _encodedSignature = abi.encodePacked(r, s, v);
  }

  function _boundAttestation(Attestation memory _attestation) public view {
    _attestation.validUntil = bound(
      _attestation.validUntil, block.timestamp, block.timestamp + MAX_ATTESTATION_VALIDITY_SECONDS
    );
    _attestation.nonce = VERIFIER.nonces(_attestation.beneficiary);
  }

  function _boundAttestationAndDeploymentConfig(
    Attestation memory _attestation,
    CreatorTokenFactory.DeploymentConfig memory _config
  ) public view {
    _boundAttestation(_attestation);
    vm.assume(_config.creator != address(0) && _config.admin != address(0));
    _config.creatorFee = bound(_config.creatorFee, 0, MAX_FEE);
    _config.adminFee = bound(_config.adminFee, 0, MAX_FEE);
    _config.attestationDigest = _attestationDigest(_attestation);
  }

  function _assertValidDeployment(
    CreatorTokenFactory.DeploymentConfig memory _config,
    CreatorToken _creatorToken
  ) public {
    assertEq(_creatorToken.name(), _config.name);
    assertEq(_creatorToken.symbol(), _config.symbol);
    assertEq(_creatorToken.tokenURI(0), _config.tokenURI);
    assertEq(_creatorToken.creator(), _config.creator);
    assertEq(_creatorToken.CREATOR_FEE_BIPS(), _config.creatorFee);
    assertEq(_creatorToken.admin(), _config.admin);
    assertEq(_creatorToken.ADMIN_FEE_BIPS(), _config.adminFee);
    assertEq(_creatorToken.REFERRER(), _config.referrer);
    assertEq(address(_creatorToken.payToken()), address(_config.payToken));

    CTBondingCurve _bondingCurve = CTBondingCurve(address(_creatorToken.BONDING_CURVE()));
    assertEq(_bondingCurve.BASE_PRICE(), _config.basePrice);
    assertEq(_bondingCurve.INFLECTION_POINT(), _config.inflectionPoint);
    assertEq(_bondingCurve.INFLECTION_PRICE(), _config.inflectionPrice);
  }
}

contract DeploymentOfFactory is CreatorTokenFactoryTest {
  function test_FactoryIsConfiguredCorrectlyAtDeployment() public {
    assertEq(address(factory.VERIFIER()), address(VERIFIER));
    assertEq(factory.domainSeparator(), VERIFIER.domainSeparator());
  }
}

contract DigestSigning is CreatorTokenFactoryTest {
  function test_ProducesADigestThatCanBeSignedAndVerified(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation
  ) public {
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    assertTrue(
      VERIFIER.verify(_attestation, factory.DEPLOY_TYPE_HASH(), factory.encode(_config), _signature)
    );
  }
}

contract TokenDeployment is CreatorTokenFactoryTest {
  // Test with a static, realistic config as a sanity check
  function test_DeploysCreatorTokenWithStaticConfig() public {
    Attestation memory _attestation = Attestation({
      beneficiary: address(0xace),
      context: address(factory),
      nonce: 0,
      validUntil: block.timestamp + MAX_ATTESTATION_VALIDITY_SECONDS
    });

    CreatorTokenFactory.DeploymentConfig memory _config = CreatorTokenFactory.DeploymentConfig({
      name: "Creator Test Token",
      symbol: "CTT",
      tokenURI: "ipfs://bafybeigwkxrxgqk27netupk5xxxput2fdjnhl4vrgy46nmyqpj4p4jdfsy",
      creator: address(0xace),
      creatorFee: 700,
      admin: address(0xb055),
      adminFee: 300,
      referrer: address(0xd00d),
      payToken: IERC20(address(0xca5)),
      basePrice: 1e6,
      linearPriceSlope: 0.1e6,
      inflectionPrice: 845e6,
      inflectionPoint: 2000,
      attestationDigest: _attestationDigest(_attestation)
    });

    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    // hardcoded, pre-calculated addresses for the test config, so we can expect the event emissions
    CreatorToken preCalculatedTokenAddress =
      CreatorToken(0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3);
    CTBondingCurve preCalculatedBondingCurve =
      CTBondingCurve(0x104fBc016F4bb334D775a19E8A6510109AC63E00);

    vm.expectEmit(true, true, true, true);
    emit CreatorTokenDeployed(preCalculatedTokenAddress, preCalculatedBondingCurve, _config);
    CreatorToken _deployedToken = factory.deploy(_attestation, _config, _signature);
    _assertValidDeployment(_config, _deployedToken);
  }

  // Fuzz the attestation and config and deploy
  function test_DeploysCreatorToken(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation
  ) public {
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    CreatorToken _deployedToken = factory.deploy(_attestation, _config, _signature);
    _assertValidDeployment(_config, _deployedToken);
  }

  function test_RevertIf_TheSignerIsNotRegistered(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation,
    string memory _badSignerSeed
  ) public {
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    (address _badSigner, uint256 _badSignerKey) = makeAddrAndKey(_badSignerSeed);
    vm.assume(_badSigner != showtimeSigner);

    bytes32 _configDigest = factory.createDigest(_config);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(_badSignerKey, _configDigest);
    bytes memory _signature = abi.encodePacked(r, s, v);

    vm.expectRevert(IShowtimeVerifier.UnknownSigner.selector);
    factory.deploy(_attestation, _config, _signature);
  }

  function test_RevertIf_TheAttestationHasBeenModified(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation,
    address _mutatedBeneficiary
  ) public {
    vm.assume(_attestation.beneficiary != _mutatedBeneficiary);
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    _attestation.beneficiary = _mutatedBeneficiary;

    vm.expectRevert(CreatorTokenFactory.CreatorTokenFactory__InvalidAttestation.selector);
    factory.deploy(_attestation, _config, _signature);
  }

  function test_RevertIf_NonceIsReused(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation
  ) public {
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    // Sign and execute the first deployment
    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);
    CreatorToken _deployedToken = factory.deploy(_attestation, _config, _signature);
    _assertValidDeployment(_config, _deployedToken);

    // Attempt to repeat the deployment and get a nonce revert
    vm.expectRevert(abi.encodeWithSelector(IShowtimeVerifier.BadNonce.selector, 1, 0));
    factory.deploy(_attestation, _config, _signature);
  }

  function test_RevertIf_NonceIsWrong(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation,
    uint256 _badNonce
  ) public {
    _badNonce = bound(_badNonce, 1, 10_000); // Well above bounds of likely nonce
    _boundAttestationAndDeploymentConfig(_attestation, _config);

    // Overwrite the nonce in the Attestation & DeploymentConfig
    _attestation.nonce += _badNonce;
    _config.attestationDigest = _attestationDigest(_attestation);

    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    // Attempt to do the deployment and get a nonce revert
    vm.expectRevert(
      abi.encodeWithSelector(
        IShowtimeVerifier.BadNonce.selector,
        VERIFIER.nonces(_attestation.beneficiary),
        _attestation.nonce
      )
    );
    factory.deploy(_attestation, _config, _signature);
  }

  function test_RevertIf_VerifierDoesNotVerifySignature(
    CreatorTokenFactory.DeploymentConfig memory _config,
    Attestation memory _attestation
  ) public {
    _boundAttestationAndDeploymentConfig(_attestation, _config);
    bytes32 _configDigest = factory.createDigest(_config);
    bytes memory _signature = _showtimeSignature(_configDigest);

    // Deploy a mock verifier that will return false from its verify methods
    IShowtimeVerifier _mockVerifier = new MockFailingVerifier();
    factory = new CreatorTokenFactory(_mockVerifier);

    vm.expectRevert(CreatorTokenFactory.CreatorTokenFactory__DeploymentNotVerified.selector);
    factory.deploy(_attestation, _config, _signature);
  }
}
