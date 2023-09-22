// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CTBondingCurve} from "src/CTBondingCurve.sol";

contract CTBondingCurveTest is Test {
  function setUp() public {}
}

contract Deployment is CTBondingCurveTest {
  function test_BondingCurveIsConfiguredAtDeployment(
    uint128 _basePrice,
    uint128 _linearPriceSlope,
    uint128 _inflectionPrice,
    uint32 _inflectionPoint
  ) public {
    CTBondingCurve _curve =
      new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    assertEq(_curve.BASE_PRICE(), _basePrice);
    assertEq(_curve.LINEAR_PRICE_SLOPE(), _linearPriceSlope);
    assertEq(_curve.INFLECTION_PRICE(), _inflectionPrice);
    assertEq(_curve.INFLECTION_POINT(), _inflectionPoint);
  }
}

contract CurveMath is CTBondingCurveTest {
  function test_DiscreetCurveParametersWorkAsExpectedRev1() public {
    // Price parameters are in 6 decimals e.g. like USDC
    uint128 _basePrice = 1e6; // c = 1
    uint128 _linearPriceSlope = 0.1e6; // b = .1
    uint128 _inflectionPrice = 845e6; // h = 845
    uint32 _inflectionPoint = 2000; // g = 2000
    CTBondingCurve _curve =
      new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    // Pre-calculated expectations, see https://www.desmos.com/calculator/tmeotsiwyi for the
    // curve calculations used to validate these
    assertEq(_curve.priceForTokenNumber(1), 1_100_211);
    assertEq(_curve.priceForTokenNumber(2), 1_200_844);
    assertEq(_curve.priceForTokenNumber(5), 1_505_275);
    assertEq(_curve.priceForTokenNumber(10), 2_021_100);
    assertEq(_curve.priceForTokenNumber(100), 13_110_000);
    assertEq(_curve.priceForTokenNumber(500), 103_750_000);
    assertEq(_curve.priceForTokenNumber(1000), 312_000_000);
    assertEq(_curve.priceForTokenNumber(2000), 1_046_000_000);
    assertEq(_curve.priceForTokenNumber(3000), 1_764_540_000);
    assertEq(_curve.priceForTokenNumber(4000), 2_290_420_000);
    assertEq(_curve.priceForTokenNumber(5000), 2_736_025_000);
    assertEq(_curve.priceForTokenNumber(10_000), 4_484_935_000);
  }

  // An arbitrary additional test case as a sanity check
  function test_DiscreetCurveParametersWorkAsExpectedRev2() public {
    // Price parameters in 18 decimals
    uint128 _basePrice = 3e18; // c = 3
    uint128 _linearPriceSlope = 2e18; // b = 2
    uint128 _inflectionPrice = 1200e18; // h = 1200
    uint32 _inflectionPoint = 10_000; // g = 10000
    CTBondingCurve _curve =
      new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    // Pre-calculated expectations
    assertEq(_curve.priceForTokenNumber(1), 5_000_012_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(2), 7_000_048_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(5), 13_000_300_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(10), 23_001_200_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(100), 203_120_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(500), 1_006_000_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(1000), 2_015_000_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(5000), 10_303_000_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(10_000), 21_203_000_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(10_001), 21_205_000_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(12_759), 27_261_240_000_000_000_000_000);
    assertEq(_curve.priceForTokenNumber(18_793), 40_139_240_000_000_000_000_000);
  }
}
