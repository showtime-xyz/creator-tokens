// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BondingCurveLib} from "src/lib/BondingCurveLib.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

contract CTBondingCurve is IBondingCurve {
  using SafeCast for uint256;

  uint128 public immutable BASE_PRICE;
  uint128 public immutable LINEAR_PRICE_SLOPE;
  uint128 public immutable INFLECTION_PRICE;
  uint32 public immutable INFLECTION_POINT;

  // TODO: documentation should make clear the expectation that inflection price,
  // which will be in the token's raw decimals, must be much greater than the
  // inflection point for this math to produce correct results in the quadratic section.
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

  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price) {
    uint32 _currentSupply = _tokenNumber.toUint32() - 1;

    _price = BASE_PRICE;
    _price += BondingCurveLib.linearSum(LINEAR_PRICE_SLOPE, _currentSupply, 1);
    _price += BondingCurveLib.sigmoid2Sum(INFLECTION_POINT, INFLECTION_PRICE, _currentSupply, 1);
  }
}
