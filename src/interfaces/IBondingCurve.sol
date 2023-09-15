// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBondingCurve {
  function priceForTokenNumber(uint256 _tokenNumber) external view returns (uint256 _price);
}
