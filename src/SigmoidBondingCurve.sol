// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BondingCurveLib} from "src/lib/BondingCurveLib.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

/// @notice Concrete bonding curve implementation using a sigmoid consisting of a quadratic
/// region and a square root region.
///
/// The quadratic region enables the price to increase rapidly when the holder pool is small. This
/// encourages viral growth at the early stages. Once a certain number of NFTs are in circulation,
/// the curve transitions to the square root region. This allows the price to increase at a slowing
/// rate, which provides better price stability and marks the transition of an NFT into a
/// "blue chip."
///
/// This bonding curve was implemented and audited for the Sound Swap protocol. This contract uses
/// `BondingCurveLib.sol` from that project and conforms to the interface expected for a Creator
/// token bonding curve.
///
/// Read more about Sound Swap bonding curve implementation here:
/// https://sound.mirror.xyz/rPnld1tfPFb3OxtfztRSjTFjc9KLUqmcV2DPCO68KMQ
contract SigmoidBondingCurve is IBondingCurve {
  using SafeCast for uint256;

  /// @notice The base price at the start of the curve.
  uint128 public immutable BASE_PRICE;

  /// @notice The linear coefficient used to fine tune the curve.
  uint128 public immutable LINEAR_PRICE_SLOPE;

  /// @notice The price at the point where the curve switches from quadratic to square root.
  uint128 public immutable INFLECTION_PRICE;

  /// @notice Where the curve switches from quadratic to square root.
  uint32 public immutable INFLECTION_POINT;

  /// @param _basePrice The base price at the start of the curve.
  /// @param _linearPriceSlope The linear coefficient used to fine tune the curve.
  /// @param _inflectionPrice The price at the point where the curve switches from quadratic to
  /// square root.
  /// @param _inflectionPoint Where the curve switches from quadratic to square root.
  /// @dev The inflection point is along the curve's x-axis, that is, the number of tokens. The
  /// other parameters are along the curve's y-axis, that is, the price. The price parameters must
  /// be in the decimals of the payment token, for example, `1e6` for USDC or `1e18` for ETH.
  ///
  /// The math used in the bonding curve library assumes that the raw value for inflection price
  /// will be much greater than the inflection point. This assumption should hold for most expected
  /// values because the price is token decimals. For example, an inflection price of 30 USDC at an
  /// inflection point of 50 tokens would mean 30e6 >> 50. If this assumption does not hold, either
  /// because the raw value of the inflection price is very low, or the inflection point is very
  /// high, this contract will not produce correct results.
  constructor(
    uint128 _basePrice,
    uint128 _linearPriceSlope,
    uint128 _inflectionPrice,
    uint32 _inflectionPoint
  ) {
    BASE_PRICE = _basePrice;
    LINEAR_PRICE_SLOPE = _linearPriceSlope;
    INFLECTION_PRICE = _inflectionPrice;
    INFLECTION_POINT = _inflectionPoint;
  }

  /// @dev See {IBondingCurve-priceForTokenNumber}
  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price) {
    uint32 _currentSupply = _tokenNumber.toUint32() - 1;

    _price = BASE_PRICE;
    _price += BondingCurveLib.linearSum(LINEAR_PRICE_SLOPE, _currentSupply, 1);
    _price += BondingCurveLib.sigmoid2Sum(INFLECTION_POINT, INFLECTION_PRICE, _currentSupply, 1);
  }
}
