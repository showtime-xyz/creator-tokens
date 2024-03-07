// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorTokenSwapRouterDegen} from "src/CreatorTokenSwapRouterDegen.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {MockIncrementingBondingCurve} from "test/mocks/MockIncrementingBondingCurve.sol";
import {IQuoterV2} from "test/interfaces/IQuoterV2.sol";

contract CreatorTokenSwapRouterDegenTest is Test {
  uint256 baseFork;

  CreatorTokenSwapRouterDegen router;
  address constant UNIVERSAL_ROUTER_ADDRESS = 0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC;
  address constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
  address constant DEGEN_ADDRESS = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;
  uint256 constant BASE_PAY_AMOUNT = 100 * 1e18; // Because DEGEN has 18 decimals
  uint24 constant LOW_FEE_TIER = 3000;
  string CREATOR_TOKEN_NAME = "Test Token";
  string CREATOR_TOKEN_SYMBOL = "TEST";
  string CREATOR_TOKEN_URI = "URI";

  address quoterV2Address = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a; // On base
  address buyer = 0x637C1Ec1d205a4E7a79c9CE4Bd100CD1d19E6080; // An address that can receive eth
  address creator = vm.addr(1);
  address admin = vm.addr(2);
  address referrer;
  uint256 creatorFee;
  uint96 creatorRoyalty;
  uint256 adminFee;

  ERC20 payToken;
  MockIncrementingBondingCurve bondingCurve;
  CreatorToken creatorToken;

  function setUp() public {
    string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
    baseFork = vm.createSelectFork(BASE_RPC_URL, 11_500_000);

    payToken = ERC20(DEGEN_ADDRESS); // DEGEN on base
    bondingCurve = new MockIncrementingBondingCurve(BASE_PAY_AMOUNT);
    creatorToken =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, CREATOR_TOKEN_URI, creator, creatorFee, creatorRoyalty, admin, adminFee, referrer, payToken, bondingCurve);
    router = new CreatorTokenSwapRouterDegen(UNIVERSAL_ROUTER_ADDRESS, WETH_ADDRESS, DEGEN_ADDRESS);

    vm.label(address(payToken), "payToken contract");
    vm.label(address(bondingCurve), "bondingCurve contract");
    vm.label(address(creatorToken), "creatorToken contract");
    vm.label(address(router), "router contract");
  }

  // Check Uniswap Docs: https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2
  function quote(uint256 _amountOut) public returns (uint256 _amountIn) {
    // struct QuoteExactOutputSingleParams {
    //     address tokenIn;
    //     address tokenOut;
    //     uint256 amount;
    //     uint24 fee;
    //     uint160 sqrtPriceLimitX96;
    // }
    IQuoterV2.QuoteExactOutputSingleParams memory params = IQuoterV2.QuoteExactOutputSingleParams(
      WETH_ADDRESS, DEGEN_ADDRESS, _amountOut, LOW_FEE_TIER, 0
    );
    (_amountIn,,,) = IQuoterV2(quoterV2Address).quoteExactOutputSingle(params);
  }

  function _assumeSafeBuyer(address _buyer) public view {
    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin && _buyer != referrer
    );
  }

  function test_BuyWithEth(address _buyer) public {
    _assumeSafeBuyer(_buyer);
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.priceToBuyNext();
    uint256 _amountOut = _tokenPrice + _creatorFee + _adminFee;
    uint256 _amountIn = quote(_amountOut);

    vm.deal(_buyer, _amountIn);

    vm.prank(_buyer);
    router.buyWithEth{value: _amountIn}(address(creatorToken), _amountOut);

    assertEq(_buyer.balance, 0, "test_BuyWithEth: Buyer Eth balance mismatch");
    assertEq(
      creatorToken.balanceOf(_buyer),
      _originalBuyerBalanceOfCreatorTokens + 1,
      "test_BuyWithEth: Buyer balance of creator tokens mismatch"
    );
    assertEq(
      creatorToken.ownerOf(creatorToken.lastId()),
      _buyer,
      "test_BuyWithEth: Buyer is not owner of token"
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice,
      "test_BuyWithEth: Creator token contract balance mismatch"
    );
    assertEq(
      creatorToken.totalSupply(),
      _originalCreatorTokenSupply + 1,
      "test_BuyWithEth: Creator token supply mismatch"
    );
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _creatorFee,
      "test_BuyWithEth: Creator balance mismatch"
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _adminFee,
      "test_BuyWithEth: Admin balance mismatch"
    );
  }

  function test_BuyWithEthWithReceiverAndSendExtraEth(address _receiver, uint256 _amountIn) public {
    _assumeSafeBuyer(_receiver);
    vm.assume(_receiver != buyer);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.priceToBuyNext();
    uint256 _amountOut = _tokenPrice + _creatorFee + _adminFee;
    uint256 _amountInQuote = quote(_amountOut);
    _amountIn = bound(_amountIn, _amountInQuote + 1, 100 ether);

    uint256 _originalReceiverBalanceOfCreatorTokens = creatorToken.balanceOf(_receiver);
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();

    vm.deal(buyer, _amountIn);
    vm.prank(buyer);
    router.buyWithEth{value: _amountIn}(address(creatorToken), _receiver, _amountOut);

    assertEq(
      buyer.balance,
      _amountIn - _amountInQuote,
      "test_BuyWithEthWithReceiver: Buyer Eth balance mismatch"
    );
    assertEq(
      creatorToken.balanceOf(_receiver),
      _originalReceiverBalanceOfCreatorTokens + 1,
      "test_BuyWithEthWithReceiver: Receiver balance of creator tokens mismatch"
    );
    assertEq(
      creatorToken.ownerOf(creatorToken.lastId()),
      _receiver,
      "test_BuyWithEthWithReceiver: Receiver is not owner of token"
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice,
      "test_BuyWithEthWithReceiver: Creator token contract balance mismatch"
    );
    assertEq(
      creatorToken.totalSupply(),
      _originalCreatorTokenSupply + 1,
      "test_BuyWithEthWithReceiver: Creator token supply mismatch"
    );
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _creatorFee,
      "test_BuyWithEthWithReceiver: Creator balance mismatch"
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _adminFee,
      "test_BuyWithEthWithReceiver: Admin balance mismatch"
    );
  }

  function test_BulkBuyWithEthAndSendExtraEth(uint256 _numOfTokens, uint256 _amountIn) public {
    _numOfTokens = bound(_numOfTokens, 1, 10);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) =
      creatorToken.priceToBuyNext(_numOfTokens);
    uint256 _amountOut = _tokenPrice + _creatorFee + _adminFee;
    uint256 _amountInQuote = quote(_amountOut);
    _amountIn = bound(_amountIn, _amountInQuote + 1, 100 ether);

    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(buyer);
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();

    vm.deal(buyer, _amountIn);
    vm.prank(buyer);
    router.bulkBuyWithEth{value: _amountIn}(address(creatorToken), _numOfTokens, (_amountOut));

    assertEq(
      buyer.balance, _amountIn - _amountInQuote, "test_BulkBuyWithEth: Buyer Eth balance mismatch"
    );
    assertEq(
      creatorToken.balanceOf(buyer),
      _originalBuyerBalanceOfCreatorTokens + _numOfTokens,
      "test_BulkBuyWithEth: Buyer balance of creator tokens mismatch"
    );
    assertEq(
      creatorToken.ownerOf(creatorToken.lastId()),
      buyer,
      "test_BulkBuyWithEth: Buyer is not owner of token"
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice,
      "test_BulkBuyWithEth: Creator token contract balance mismatch"
    );
    assertEq(
      creatorToken.totalSupply(),
      _originalCreatorTokenSupply + _numOfTokens,
      "test_BulkBuyWithEth: Creator token supply mismatch"
    );
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _creatorFee,
      "test_BulkBuyWithEth: Creator balance mismatch"
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _adminFee,
      "test_BulkBuyWithEth: Admin balance mismatch"
    );
  }

  function test_BulkBuyWithEthWithReceiver(address _buyer, address _receiver, uint256 _numOfTokens)
    public
  {
    _assumeSafeBuyer(_buyer);
    _assumeSafeBuyer(_receiver);
    vm.assume(_buyer != _receiver);
    _numOfTokens = bound(_numOfTokens, 1, 10);
    uint256 _originalReceiverBalanceOfCreatorTokens = creatorToken.balanceOf(_receiver);
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfCreator = payToken.balanceOf(creator);
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(admin);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) =
      creatorToken.priceToBuyNext(_numOfTokens);

    uint256 _amountIn = quote(_tokenPrice + _creatorFee + _adminFee);
    vm.deal(_buyer, _amountIn);

    vm.prank(_buyer);
    router.bulkBuyWithEth{value: _amountIn}(
      address(creatorToken), _receiver, _numOfTokens, (_tokenPrice + _creatorFee + _adminFee)
    );

    assertEq(_buyer.balance, 0, "test_BulkBuyWithEthWithReceiver: Buyer Eth balance mismatch");
    assertEq(
      creatorToken.balanceOf(_receiver),
      _originalReceiverBalanceOfCreatorTokens + _numOfTokens,
      "test_BulkBuyWithEthWithReceiver: Receiver balance of creator tokens mismatch"
    );
    assertEq(
      creatorToken.ownerOf(creatorToken.lastId()),
      _receiver,
      "test_BulkBuyWithEthWithReceiver: Receiver is not owner of token"
    );
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice,
      "test_BulkBuyWithEthWithReceiver: Creator token contract balance mismatch"
    );
    assertEq(
      creatorToken.totalSupply(),
      _originalCreatorTokenSupply + _numOfTokens,
      "test_BulkBuyWithEthWithReceiver: Creator token supply mismatch"
    );
    assertEq(
      payToken.balanceOf(creator),
      _originalPayTokenBalanceOfCreator + _creatorFee,
      "test_BulkBuyWithEthWithReceiver: Creator balance mismatch"
    );
    assertEq(
      payToken.balanceOf(admin),
      _originalPayTokenBalanceOfAdmin + _adminFee,
      "test_BulkBuyWithEthWithReceiver: Admin balance mismatch"
    );
  }
}
