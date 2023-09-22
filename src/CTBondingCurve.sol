// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BondingCurveLib} from "src/lib/BondingCurveLib.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

contract CTBondingCurve is IBondingCurve {
  using SafeCast for uint256;

  uint128 public immutable basePrice;
  uint128 public immutable linearPriceSlope;
  uint128 public immutable inflectionPrice;
  uint32 public immutable inflectionPoint;

  // TODO: documentation should make clear the expectation that inflection price,
  // which will be in the token's raw decimals, must be much greater than the
  // inflection point for this math to produce correct results in the quadratic section.
  constructor(
    uint128 _basePrice,
    uint128 _linearPriceSlope,
    uint128 _inflectionPrice,
    uint32 _inflectionPoint
  ) {
    basePrice = _basePrice;
    linearPriceSlope = _linearPriceSlope;
    inflectionPrice = _inflectionPrice;
    inflectionPoint = _inflectionPoint;
  }

  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price) {
    uint32 _currentSupply = _tokenNumber.toUint32() - 1;

    _price = basePrice;
    _price += BondingCurveLib.linearSum(linearPriceSlope, _currentSupply, 1);
    _price += BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, _currentSupply, 1);
  }
}
