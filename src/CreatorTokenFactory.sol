// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreatorToken} from "src/CreatorToken.sol";
import {SigmoidBondingCurve} from "src/SigmoidBondingCurve.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IShowtimeVerifier, Attestation} from "src/lib/IShowtimeVerifier.sol";

/// @notice A factory contract to deploy CreatorToken contracts with associated
/// SigmoidBondingCurve contracts. The factory is integrated with the ShowtimeVerifier. Before
/// deploying a CreatorToken, the factory will ask the verifier to verify that the deployment
/// request has been approved via signature from a whitelisted verifier address. In addition to the
/// method used for deployment, this contract contains helpers related to generating the signature
/// for verifying the deployment request.
contract CreatorTokenFactory {
  /// @notice All the configuration parameters required to deploy a CreatorToken and its
  /// SigmoidBondingCurve.
  /// @param name The name of the ERC721 token.
  /// @param symbol The symbol of the ERC721 token.
  /// @param tokenURI The URI for the creator token.
  /// @param creator Address of the creator.
  /// @param creatorFee Creator fee in BIPs.
  /// @param creatorRoyalty Creator royalty fee in BIPs.
  /// @param admin Address of the admin.
  /// @param adminFee Admin fee in BIPs.
  /// @param referrer Address of the referrer.
  /// @param payToken ERC20 token used for payments.
  /// @param basePrice The base price at the start of the curve.
  /// @param linearPriceSlope The linear coefficient used to fine tune the curve.
  /// @param inflectionPrice The price at the point where the curve switches from quadratic to
  /// square root.
  /// @param inflectionPoint Where the curve switches from quadratic to square root.
  /// @param attestationDigest The ERC712 digest of the Attestation object for this deployment.
  struct DeploymentConfig {
    string name;
    string symbol;
    string tokenURI;
    address creator;
    uint256 creatorFee;
    uint96 creatorRoyalty;
    address admin;
    uint256 adminFee;
    address referrer;
    IERC20 payToken;
    uint128 basePrice;
    uint128 linearPriceSlope;
    uint128 inflectionPrice;
    uint32 inflectionPoint;
    bytes32 attestationDigest;
  }

  /// @notice Emitted when a new CreatorToken and SigmoidBondingCurve pair is successfully
  /// deployed.
  /// @param creatorToken The address of the newly deployed CreatorToken contract.
  /// @param bondingCurve The address of the newly deployed SigmoidBondingCurve contract.
  /// @param config The config object used to execute this deployment.
  event CreatorTokenDeployed(
    CreatorToken indexed creatorToken,
    SigmoidBondingCurve indexed bondingCurve,
    DeploymentConfig config
  );

  /// @notice Thrown when a deployment fails because it is not verified by the ShowtimeVerifier.
  error CreatorTokenFactory__DeploymentNotVerified();

  /// @notice Thrown when the Attestation object provided during deployment does not match with the
  /// Attestation digest included in the DeploymentConfig.
  error CreatorTokenFactory__InvalidAttestation();

  /// @notice The ERC712 compatible type data used for signing over a DeploymentConfig object.
  bytes public constant DEPLOY_TYPE =
    "DeploymentConfig(string name,string symbol,string tokenURI,address creator,uint256 creatorFee,uint96 creatorRoyalty,address admin,uint256 adminFee,address referrer,address payToken,uint128 basePrice,uint128 linearPriceSlope,uint128 inflectionPrice,uint32 inflectionPoint,bytes32 attestationDigest)";

  /// @notice The hash of `DEPLOY_TYPE` data used for generating ERC712 signatures.
  bytes32 public constant DEPLOY_TYPE_HASH = keccak256(DEPLOY_TYPE);

  /// @notice The ShowtimeVerifier contract that will be used to verify this contract has been
  /// explicitly approved by a whitelisted Showtime signer address.
  IShowtimeVerifier public immutable VERIFIER;

  /// @notice The ERC712 domain separator *used by the ShowtimeVerifier contract*. This must be set
  /// to the domain separator from the ShowtimeVerifier instance that will be used by this factory.
  /// @dev Note that the ShowtimeVerifier contract derives its domain separator from its address
  /// and the chainId, so by making this an immutable value on this contract, there is an implicit
  /// (and very likely safe) assumption that those two things can never change, or this factory
  /// instance will become un-useable.
  bytes32 private immutable DOMAIN_SEPARATOR;

  /// @notice The ERC712 compatible hash of the Attestation type.
  /// @dev Matches type hash in ShowtimeVerifier.
  bytes32 private constant ATTESTATION_TYPE_HASH =
    keccak256("Attestation(address beneficiary,address context,uint256 nonce,uint256 validUntil)");

  /// @param _verifier Address of the ShowtimeVerifier contract that will be used by the factory.
  /// @param _domainSeparator Domain separator of the ShowtimeVerifier that will be used by the
  /// factory.
  constructor(IShowtimeVerifier _verifier, bytes32 _domainSeparator) {
    VERIFIER = _verifier;
    DOMAIN_SEPARATOR = _domainSeparator;
  }

  /// @return The ERC712 domain separator used by this factory, which must match the one used by
  /// the ShowtimeVerifier it interacts with.
  function domainSeparator() external view returns (bytes32) {
    return DOMAIN_SEPARATOR;
  }

  /// @notice Generates the ERC712 compatible encoding of a given DeploymentConfig.
  /// @param _config The DeploymentConfig struct that will be encoded.
  /// @return The ERC712 encoded data for the provided DeploymentConfig struct.
  function encode(DeploymentConfig memory _config) public pure returns (bytes memory) {
    // We nest these calls to `abi.encodePacked` to avoid stack too deep errors which
    // crop up when we send all the variables to abi.encodePacked at once. This occurs only
    // when the optimizer is off. When the optimizer is on it should (?) remove the nested
    // calls anyway. Either way, the result from the function should be the same.
    return abi.encodePacked(
      abi.encodePacked(
        keccak256(bytes(_config.name)),
        keccak256(bytes(_config.symbol)),
        keccak256(bytes(_config.tokenURI)),
        uint256(uint160(_config.creator)),
        _config.creatorFee,
        uint256(uint160(_config.admin)),
        uint96(_config.creatorRoyalty),
        _config.adminFee,
        uint256(uint160(_config.referrer)),
        uint256(uint160(address(_config.payToken))),
        uint256(_config.basePrice),
        uint256(_config.linearPriceSlope)
      ),
      uint256(_config.inflectionPrice),
      uint256(_config.inflectionPoint),
      _config.attestationDigest
    );
  }

  /// @notice Generates the ERC712 compatible digest of a given DeploymentConfig.
  /// @param _config The DeploymentCongig struct that will be used to generate an ERC712 digest.
  /// @return _digest The ERC712 compatible digest for the provided DeploymentConfig struct.
  /// @dev This helper method can be used offchain to assist in generating the appropriate ERC712
  /// signature. The data returned by this method is what the signer address should sign.
  function createDigest(DeploymentConfig memory _config) external view returns (bytes32 _digest) {
    bytes32 _configHash = keccak256(abi.encodePacked(DEPLOY_TYPE_HASH, encode(_config)));
    _digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _configHash));
  }

  /// @notice Deploys a CreatorToken and SigmoidBondingCurve pair for the given configuration,
  /// provided that configuration has been attested to and signed by an address with authority to
  /// do so according to the ShowtimeVerifier contract.
  /// @param _attestation The unsigned Attestation data for the deployment being requested, as
  /// defined by the ShowtimeVerifier contract. The digest of this Attestation data must match the
  /// digest data provided in the DeploymentConfig it attests for.
  /// @param _config The configuration data for the would-be token and bonding curve contracts.
  /// @param _signature A signature of the `_config` data from a valid Showtime verifier address.
  /// @return _creatorToken The address of the newly deployed CreatorToken contract.
  /// @dev Reverts if the Attestation does not match the digest provided in the in the
  /// DeploymentConfig. This ensures that the signature data must change if the Attestation changes.
  /// Also reverts if the ShowtimeVerifier does not verify the signature provided.
  function deploy(
    Attestation calldata _attestation,
    DeploymentConfig memory _config,
    bytes calldata _signature
  ) external returns (CreatorToken _creatorToken) {
    bool _verified =
      VERIFIER.verifyAndBurn(_attestation, DEPLOY_TYPE_HASH, encode(_config), _signature);
    if (!_verified) revert CreatorTokenFactory__DeploymentNotVerified();
    if (_config.attestationDigest != _attestationDigest(_attestation)) {
      revert CreatorTokenFactory__InvalidAttestation();
    }

    SigmoidBondingCurve _bondingCurve =
    new SigmoidBondingCurve(_config.basePrice, _config.linearPriceSlope, _config.inflectionPrice, _config.inflectionPoint);

    _creatorToken = new CreatorToken(
      _config.name,
      _config.symbol,
      _config.tokenURI,
      _config.creator,
      _config.creatorFee,
      _config.creatorRoyalty,
      _config.admin,
      _config.adminFee,
      _config.referrer,
      _config.payToken,
      _bondingCurve
    );
    emit CreatorTokenDeployed(_creatorToken, _bondingCurve, _config);
  }

  /// @notice Generates the ERC712 compatible digest of an Attestation object used by the
  /// ShowtimeVerifier.
  /// @dev Matches implementation in the ShowtimeVerifier contract.
  function _attestationDigest(Attestation calldata _attestation) private view returns (bytes32) {
    bytes memory encodedStruct = abi.encode(
      _attestation.beneficiary, _attestation.context, _attestation.nonce, _attestation.validUntil
    );
    bytes32 structHash = keccak256(abi.encodePacked(ATTESTATION_TYPE_HASH, encodedStruct));
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
  }
}
