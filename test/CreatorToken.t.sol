// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract CreatorTokenTest is Test {
  IERC20 public payToken;
  CreatorToken public creatorToken;
  address public creator = address(0xc2ea702);

  string CREATOR_TOKEN_NAME = "Test Token";
  string CREATOR_TOKEN_SYMBOL = "TEST";

  string PAY_TOKEN_NAME = "Payment Token";
  string PAY_TOKEN_SYMBOL = "PAY";
  uint256 BASE_PAY_AMOUNT = 1e18; // Because our test token has 18 decimals

  event Minted(address indexed _to, uint256 indexed _tokenId, uint256 _paymentAmount);

  function setUp() public {
    payToken = new ERC20(PAY_TOKEN_NAME, PAY_TOKEN_SYMBOL);
    creatorToken = new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, creator, payToken);
  }
}

contract Deployment is CreatorTokenTest {
  function test_TokenIsConfiguredAtDeployment() public {
    assertEq(creatorToken.name(), CREATOR_TOKEN_NAME);
    assertEq(creatorToken.symbol(), CREATOR_TOKEN_SYMBOL);
    assertEq(creatorToken.creator(), creator);
    assertEq(address(creatorToken.payToken()), address(payToken));
  }

  function test_FirstTokenIsMintedToCreator() public {
    assertEq(creatorToken.balanceOf(creator), 1);
    assertEq(creatorToken.ownerOf(1), creator);
  }
}

contract Minting is CreatorTokenTest {
  function test_SecondTokenIsMintedForOnePaymentToken(address _minter) public {
    vm.assume(_minter != address(0) && _minter != address(creatorToken));
    uint256 originalMinterBalance = creatorToken.balanceOf(_minter);

    deal(address(payToken), _minter, BASE_PAY_AMOUNT);

    vm.startPrank(_minter);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.payAndMint(BASE_PAY_AMOUNT);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_minter), originalMinterBalance + 1);
    assertEq(payToken.balanceOf(_minter), 0);
    assertEq(payToken.balanceOf(address(creatorToken)), BASE_PAY_AMOUNT);
  }

  function test_PayAndMintWithMintToAddress(address _minter, address _mintTo) public {
    vm.assume(_minter != address(0) && _minter != address(creatorToken));
    vm.assume(_mintTo != address(0) && _mintTo != address(creatorToken));
    uint256 originalMinterBalance = creatorToken.balanceOf(_mintTo);

    deal(address(payToken), _minter, BASE_PAY_AMOUNT);

    vm.startPrank(_minter);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.payAndMint(_mintTo, BASE_PAY_AMOUNT);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_mintTo), originalMinterBalance + 1);
    assertEq(payToken.balanceOf(_minter), 0);
    assertEq(payToken.balanceOf(address(creatorToken)), BASE_PAY_AMOUNT);
  }

  function test_EmitsMintedEvent(address _minter) public {
    vm.assume(_minter != address(0) && _minter != address(creatorToken));
    deal(address(payToken), _minter, BASE_PAY_AMOUNT);

    vm.startPrank(_minter);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectEmit(true, true, true, true);
    emit Minted(_minter, creatorToken.lastId() + 1, BASE_PAY_AMOUNT);
    creatorToken.payAndMint(BASE_PAY_AMOUNT);
    vm.stopPrank();
  }

  function test_RevertIf_MintPriceExceedsMaxPayment(uint256 _maxPayment) public {
    vm.assume(_maxPayment < BASE_PAY_AMOUNT);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxPaymentExceeded.selector, BASE_PAY_AMOUNT, _maxPayment
      )
    );
    creatorToken.payAndMint(_maxPayment);
  }
}
