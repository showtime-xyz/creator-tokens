// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CTBondingCurve} from "src/CTBondingCurve.sol";

contract CTBondingCurveTest is Test {
  function setUp() public {}
}

contract Deployment is CTBondingCurveTest {
  function test_BondingCurveIsConfiguredAtDeployment(
    uint256 _basePrice,
    uint128 _linearPriceSlope,
    uint128 _inflectionPrice,
    uint32 _inflectionPoint
  ) public {
    CTBondingCurve _curve =
      new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    assertEq(_curve.basePrice(), _basePrice);
    assertEq(_curve.linearPriceSlope(), _linearPriceSlope);
    assertEq(_curve.inflectionPrice(), _inflectionPrice);
    assertEq(_curve.inflectionPoint(), _inflectionPoint);
  }
}
