// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";

contract MockIncrementingBondingCurve is IBondingCurve {
  uint256 private basePrice;

  constructor(uint256 _basePrice) {
    basePrice = _basePrice;
  }

  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price) {
    _price = _tokenNumber * basePrice;
  }
}
