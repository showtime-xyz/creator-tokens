// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SwapRouter} from "src/SwapRouter.sol";

abstract contract SwapRouterTest is Test {
  SwapRouter router;

  function setUp() public {
    router = new SwapRouter();
  }

  function testSwap() public {
    router.buyWithEth(address(this), , msg.value);
  }
}
