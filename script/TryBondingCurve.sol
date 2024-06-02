// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {SigmoidBondingCurve} from "src/SigmoidBondingCurve.sol";

contract TryBondingCurve is Script {
  function run() public {
    uint128 _basePrice = 100_000_000_000_000;
    uint128 _linearPriceSlope = 1_000_000_000_000_000_000_000;
    uint128 _inflectionPrice = 100_000_000_000_000_000_000_000;
    uint32 _inflectionPoint = 400;

    SigmoidBondingCurve _bondingCurve =
      new SigmoidBondingCurve(_basePrice, _linearPriceSlope, _inflectionPrice, _inflectionPoint);

    console2.log("Deployed bonding curve contract address %s", address(_bondingCurve));
    uint256 _tokenNumber = _bondingCurve.priceForTokenNumber(1);
    console2.log("print(f'1: {%s/10**18:_}')", _tokenNumber);

    uint256 _tokenNumber2 = _bondingCurve.priceForTokenNumber(2);
    console2.log("print(f'2: {%s/10**18:_}')", _tokenNumber2);

    uint256 _tokenNumber3 = _bondingCurve.priceForTokenNumber(3);
    console2.log("print(f'3: {%s/10**18:_}')", _tokenNumber3);

    uint256 _tokenNumber10 = _bondingCurve.priceForTokenNumber(10);
    console2.log("print(f'10: {%s/10**18:_}')", _tokenNumber10);

    uint256 _tokenNumber100 = _bondingCurve.priceForTokenNumber(100);
    console2.log("print(f'100: {%s/10**18:_}')", _tokenNumber100);

    uint256 _tokenNumber200 = _bondingCurve.priceForTokenNumber(200);
    console2.log("print(f'200: {%s/10**18:_}')", _tokenNumber200);

    uint256 _tokenNumber300 = _bondingCurve.priceForTokenNumber(300);
    console2.log("print(f'300: {%s/10**18:_}')", _tokenNumber300);

    uint256 _tokenNumber400 = _bondingCurve.priceForTokenNumber(400);
    console2.log("print(f'400: {%s/10**18:_}')", _tokenNumber400);

    uint256 _tokenNumber500 = _bondingCurve.priceForTokenNumber(500);
    console2.log("print(f'500: {%s/10**18:_}')", _tokenNumber500);

    uint256 _tokenNumber600 = _bondingCurve.priceForTokenNumber(600);
    console2.log("print(f'600: {%s/10**18:_}')", _tokenNumber600);

    uint256 _tokenNumber700 = _bondingCurve.priceForTokenNumber(700);
    console2.log("print(f'700: {%s/10**18:_}')", _tokenNumber700);

    uint256 _tokenNumber800 = _bondingCurve.priceForTokenNumber(800);
    console2.log("print(f'800: {%s/10**18:_}')", _tokenNumber800);

    uint256 _tokenNumber900 = _bondingCurve.priceForTokenNumber(900);
    console2.log("print(f'900: {%s/10**18:_}')", _tokenNumber900);

    uint256 _tokenNumber1000 = _bondingCurve.priceForTokenNumber(1000);
    console2.log("print(f'1000: {%s/10**18:_}')", _tokenNumber1000);
  }
}
