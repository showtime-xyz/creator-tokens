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

    assertEq(_curve.basePrice(), _basePrice);
    assertEq(_curve.linearPriceSlope(), _linearPriceSlope);
    assertEq(_curve.inflectionPrice(), _inflectionPrice);
    assertEq(_curve.inflectionPoint(), _inflectionPoint);
  }
}

contract CurveMath is CTBondingCurveTest {
    function test_DiscreetCurveParametersWorkAsExpectedRev1() public {
        // Price parameters are in 6 decimals e.g. like USDC
        uint128 _basePrice = 1e6; // c = 1
        uint128 _linearPriceSlope = 0.1e6; // b = .1
        uint128 _inflectionPrice = 845e6; // h = 845
        uint32 _inflectionPoint = 2000; // g = 2000
        CTBondingCurve _curve = new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

        // Pre-calculated expectations, see https://www.desmos.com/calculator/tmeotsiwyi for the
        // curve calculations used to validate these
        assertEq(_curve.priceForTokenNumber(1), 1100211);
        assertEq(_curve.priceForTokenNumber(2), 1200844);
        assertEq(_curve.priceForTokenNumber(5), 1505275);
        assertEq(_curve.priceForTokenNumber(10), 2021100);
        assertEq(_curve.priceForTokenNumber(100), 13110000);
        assertEq(_curve.priceForTokenNumber(500), 103750000);
        assertEq(_curve.priceForTokenNumber(1000), 312000000);
        assertEq(_curve.priceForTokenNumber(2000), 1046000000);
        assertEq(_curve.priceForTokenNumber(3000), 1764540000);
        assertEq(_curve.priceForTokenNumber(4000), 2290420000);
        assertEq(_curve.priceForTokenNumber(5000), 2736025000);
        assertEq(_curve.priceForTokenNumber(10000), 4484935000);
    }

    // An arbitrary additional test case as a sanity check
    function test_DiscreetCurveParametersWorkAsExpectedRev2() public {
        // Price parameters in 18 decimals
        uint128 _basePrice = 3e18; // c = 3
        uint128 _linearPriceSlope = 2e18; // b = 2
        uint128 _inflectionPrice = 1200e18; // h = 1200
        uint32 _inflectionPoint = 10000; // g = 10000
        CTBondingCurve _curve = new CTBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

        // Pre-calculated expectations
        assertEq(_curve.priceForTokenNumber(1), 5000012000000000000);
        assertEq(_curve.priceForTokenNumber(2), 7000048000000000000);
        assertEq(_curve.priceForTokenNumber(5), 13000300000000000000);
        assertEq(_curve.priceForTokenNumber(10), 23001200000000000000);
        assertEq(_curve.priceForTokenNumber(100), 203120000000000000000);
        assertEq(_curve.priceForTokenNumber(500), 1006000000000000000000);
        assertEq(_curve.priceForTokenNumber(1000), 2015000000000000000000);
        assertEq(_curve.priceForTokenNumber(5000), 10303000000000000000000);
        assertEq(_curve.priceForTokenNumber(10000), 21203000000000000000000);
        assertEq(_curve.priceForTokenNumber(10001), 21205000000000000000000);
        assertEq(_curve.priceForTokenNumber(12759), 27261240000000000000000);
        assertEq(_curve.priceForTokenNumber(18793), 40139240000000000000000);
    }
}
