// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreatorToken} from "src/CreatorToken.sol";
import {SigmoidBondingCurve} from "src/SigmoidBondingCurve.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IShowtimeVerifier, Attestation} from "src/lib/IShowtimeVerifier.sol";

contract CreatorTokenFactory {
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

  event CreatorTokenDeployed(
    CreatorToken indexed creatorToken,
    SigmoidBondingCurve indexed bondingCurve,
    DeploymentConfig config
  );

  error CreatorTokenFactory__DeploymentNotVerified();
  error CreatorTokenFactory__InvalidAttestation();

  bytes public constant DEPLOY_TYPE =
    "DeploymentConfig(string name,string symbol,string tokenURI,address creator,uint256 creatorFee,uint96 creatorRoyalty,address admin,uint256 adminFee,address referrer,address payToken,uint128 basePrice,uint128 linearPriceSlope,uint128 inflectionPrice,uint32 inflectionPoint,bytes32 attestationDigest)";

  bytes32 public constant DEPLOY_TYPE_HASH = keccak256(DEPLOY_TYPE);

  IShowtimeVerifier public immutable VERIFIER;

  // TODO: dev comment explaining this is the domain separator from the verifier that technically
  // can change if chainId or
  // the verifier contract address change (latter can't happen if we keep the verifier hardcoded)
  bytes32 private immutable DOMAIN_SEPARATOR;

  /// @dev Matches type hash in ShowtimeVerifier
  bytes32 private constant ATTESTATION_TYPE_HASH =
    keccak256("Attestation(address beneficiary,address context,uint256 nonce,uint256 validUntil)");

  constructor(IShowtimeVerifier _verifier, bytes32 _domainSeparator) {
    VERIFIER = _verifier;
    DOMAIN_SEPARATOR = _domainSeparator;
  }

  function domainSeparator() external view returns (bytes32) {
    return DOMAIN_SEPARATOR;
  }

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

  function createDigest(DeploymentConfig memory _config) external view returns (bytes32 _digest) {
    bytes32 _configHash = keccak256(abi.encodePacked(DEPLOY_TYPE_HASH, encode(_config)));
    _digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _configHash));
  }

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

  /// @dev Matches implementation in ShowtimeVerifier
  function _attestationDigest(Attestation calldata _attestation) private view returns (bytes32) {
    bytes memory encodedStruct = abi.encode(
      _attestation.beneficiary, _attestation.context, _attestation.nonce, _attestation.validUntil
    );
    bytes32 structHash = keccak256(abi.encodePacked(ATTESTATION_TYPE_HASH, encodedStruct));
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
  }
}
