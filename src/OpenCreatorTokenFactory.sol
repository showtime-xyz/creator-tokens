// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreatorToken} from "src/CreatorToken.sol";
import {SigmoidBondingCurve} from "src/SigmoidBondingCurve.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IShowtimeVerifier, Attestation} from "src/lib/IShowtimeVerifier.sol";

/// @notice Identical as CreatorTokenFactory, without verifier logic.
contract OpenCreatorTokenFactory {
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

  /// @notice Deploys a CreatorToken and SigmoidBondingCurve pair for the given configuration.
  /// @param _config The configuration data for the would-be token and bonding curve contracts.
  /// @return _creatorToken The address of the newly deployed CreatorToken contract.
  function deploy(DeploymentConfig memory _config) external returns (CreatorToken _creatorToken) {
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
}
