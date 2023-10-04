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

  // These are the parameters proposed by showtime for use in production. We test them
  // here explicitly to make sure they're working as expected. For a graph of these expected
  // results see: https://www.desmos.com/calculator/ojtgvjf94q
  function test_DiscreetCurveParametersProposedForProductionUseWorkAsExpected() public {
    // Price parameters in 6 decimals like USDC
    uint128 _basePrice = 1e6; // c = 1 USDC
    uint128 _linearPriceSlope = 0; // b = 0 USDC
    uint128 _inflectionPrice = 44e6; // h = 44 USDC
    uint32 _inflectionPoint = 50; // g = 50 tokens

    CTBondingCurve _curve =
      new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    // forgefmt: disable-start
    assertEq(_curve.priceForTokenNumber(1), 1_017_600);    // 1st    token is  $1.0176
    assertEq(_curve.priceForTokenNumber(2), 1_070_400);    // 2nd    token is  $1.0704
    assertEq(_curve.priceForTokenNumber(3), 1_158_400);    // 3rd    token is  $1.1584
    assertEq(_curve.priceForTokenNumber(4), 1_281_600);    // 4th    token is  $1.2816
    assertEq(_curve.priceForTokenNumber(5), 1_440_000);    // 5th    token is  $1.4400
    assertEq(_curve.priceForTokenNumber(10), 2_760_000);   // 10th   token is  $2.7600
    assertEq(_curve.priceForTokenNumber(20), 8_040_000);   // 20th   token is  $8.0400
    assertEq(_curve.priceForTokenNumber(30), 16_840_000);  // 30th   token is  $16.8400
    assertEq(_curve.priceForTokenNumber(40), 29_160_000);  // 40th   token is  $29.1600
    assertEq(_curve.priceForTokenNumber(50), 45_000_000);  // 50th   token is  $45.0400
    assertEq(_curve.priceForTokenNumber(51), 46_760_000);  // 51st   token is  $46.7600 | 46.726  (-0.034)
    assertEq(_curve.priceForTokenNumber(60), 59_080_000);  // 60th   token is  $59.0800 | 60.032  ( 0.952)
    assertEq(_curve.priceForTokenNumber(70), 71_400_000);  // 70th   token is  $71.4000 | 71.984  ( 0.584)
    assertEq(_curve.priceForTokenNumber(80), 81_960_000);  // 80th   token is  $81.9600 | 82.132  ( 0.172)
    assertEq(_curve.priceForTokenNumber(90), 90_760_000);  // 90th   token is  $90.7600 | 91.173  ( 0.413)
    assertEq(_curve.priceForTokenNumber(100), 99_560_000); // 100th  token is  $99.5600 | 99.387  (-0.173)
    assertEq(_curve.priceForTokenNumber(1000), 386_440_000);// 1000th token is $386.4400 | 387.098 ( 0.658)
    // forgefmt: disable-end
  }
}
