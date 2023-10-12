// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SwapRouter} from "src/SwapRouter.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {MockIncrementingBondingCurve} from "test/mocks/MockIncrementingBondingCurve.sol";

contract SwapRouterTest is Test {
  uint256 baseFork;

  SwapRouter router;
  address user = address(0x1);
  address tokenAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  address creatorTokenAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // On base
  address creator = address(0x2);
  address admin = address(0x3);
  address referrer;
  uint256 creatorFee;
  uint96 creatorRoyalty;
  uint256 adminFee;
  uint256 BASE_PAY_AMOUNT = 1e6; // Because USDC has 6 decimals

  string CREATOR_TOKEN_NAME = "Test Token";
  string CREATOR_TOKEN_SYMBOL = "TEST";
  string CREATOR_TOKEN_URI = "URI";

  ERC20 payToken;
  MockIncrementingBondingCurve bondingCurve;
  CreatorToken creatorToken;

  function setUp() public {
    string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    baseFork = vm.createSelectFork(BASE_RPC_URL);
    vm.rollFork(5_129_051);

    payToken = ERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC on base
    bondingCurve = new MockIncrementingBondingCurve(BASE_PAY_AMOUNT);
    creatorToken =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);

    router = new SwapRouter();
    vm.deal(user, 1 ether);
  }

  function test_Swap() public {
    uint256 originalUserBalance = user.balance;
    uint256 originalTokenBalance = IERC20(tokenAddress).balanceOf(address(router));

    vm.prank(user);
    // _maxPayment has to be in USDC units
    router.buyWithEth{value: 1 ether}(address(creatorToken), user, type(uint256).max);

    assertEq(user.balance, originalUserBalance - 1 ether);
    assertEq(creatorToken.balanceOf(user), 1);
    assertTrue(
      IERC20(tokenAddress).balanceOf(address(router)) > originalTokenBalance,
      "user should have more tokens"
    );
    console2.log("originalTokenBalance", originalTokenBalance);
    console2.log(
      "IERC20(tokenAddress).balanceOf(address(router))",
      IERC20(tokenAddress).balanceOf(address(router))
    );
  }
}
