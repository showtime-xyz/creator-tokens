// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniversalRouter} from "src/lib/IUniversalRouter.sol";
import {ICreatorToken} from "src/interfaces/ICreatorToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/// @title CreatorTokenSwapRouter
/// @notice A contract for swapping ETH to USDC and then buying Creator Tokens.
/// @dev Make sure to get a quote for ETH to Creator Token conversion before interacting.
contract CreatorTokenSwapRouter {
  /// @notice Uniswap UniversalRouter interface which is used to execute trades.
  IUniversalRouter private immutable UNIVERSAL_ROUTER;
  /// @notice Address of the Wrapped Ether (WETH) token.
  address public immutable WETH_ADDRESS;
  /// @notice Address of the USDC token.
  address public immutable USDC_ADDRESS;

  /// @notice Command bytes used for specific operations such as WRAP_ETH(0x0b),
  /// V3_SWAP_EXACT_OUT(0x01), and UNWRAP_WETH(0x0c).
  bytes private constant COMMANDS =
    abi.encodePacked(bytes1(uint8(0x0b)), bytes1(uint8(0x01)), bytes1(uint8(0x0c)));
  /// @notice Low fee tier for Uniswap V3 WETH-USDC swaps.
  bytes3 private constant LOW_FEE_TIER = bytes3(uint24(500));

  /// @notice Path for swapping WETH to USDC.
  bytes private path;

  /// @notice Contract constructor sets up the Universal Router and token addresses.
  /// @param _universalRouter Address of the Universal Router contract.
  /// @param _wethAddress Address of the WETH token contract.
  /// @param _usdcAddress Address of the USDC token contract.
  constructor(address _universalRouter, address _wethAddress, address _usdcAddress) {
    UNIVERSAL_ROUTER = IUniversalRouter(_universalRouter);
    WETH_ADDRESS = _wethAddress;
    USDC_ADDRESS = _usdcAddress;
    // WETH -> USDC, order is switched because of V3_SWAP_EXACT_OUT
    path =
      bytes.concat(bytes20(address(USDC_ADDRESS)), LOW_FEE_TIER, bytes20(address(WETH_ADDRESS)));
  }

  /// @notice Buys a Creator Token with ETH from the caller.
  /// @dev Transactions calling this function must include an ETH payment as its `value`. This ETH
  /// is then swapped for the equivalent amount of USDC needed to purchase the Creator Token.
  /// @dev Ensure that the ETH `value` sent with the transaction is equal to or greater than
  /// the amount of USDC required for the purchase.
  /// @dev You can get a quote for the amount of ETH you have to pay to get a certain amount of USDC
  /// by calling Uniswap's `QuoterV2` contract off-chain. Check Uniswap docs:
  /// https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and `quote` function
  /// in `test/SwapRouter.fork.8453.t.sol.sol`
  /// @param _creatorToken Address of the Creator Token contract.
  /// @param _maxPayment Maximum amount of USDC willing to be paid for the token.
  /// @return _amountOut The amount of USDC paid.
  function buyWithEth(address _creatorToken, uint256 _maxPayment)
    external
    payable
    returns (uint256 _amountOut)
  {
    _amountOut = buyWithEth(_creatorToken, msg.sender, _maxPayment);
  }

  /// @notice Buys creator tokens with ETH and sends them to a specified address.
  /// @dev Transactions calling this function must include an ETH payment as its `value`. This ETH
  /// is then swapped for the equivalent amount of USDC needed to purchase the Creator Token.
  /// @dev Ensure that the ETH `value` sent with the transaction is equal to or greater than
  /// the amount of USDC required for the purchase.
  /// @dev You can get a quote for the amount of ETH you have to pay to get a certain amount of USDC
  /// by calling Uniswap's `QuoterV2` contract off-chain. Check Uniswap docs:
  /// https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and `quote` function
  /// in `test/SwapRouter.fork.8453.t.sol.sol`
  /// @param _creatorToken The address of the creator token to buy.
  /// @param _to The address to send the purchased tokens.
  /// @param _maxPayment The maximum amount of USDC to be paid.
  /// @return _amountOut The amount of USDC paid.
  function buyWithEth(address _creatorToken, address _to, uint256 _maxPayment)
    public
    payable
    returns (uint256 _amountOut)
  {
    _swapEthForUSDC(_creatorToken, 1, msg.value);
    _approveCreatorToken(_creatorToken, _maxPayment);
    _amountOut = ICreatorToken(_creatorToken).buy(_to, _maxPayment);
  }

  /// @notice Buys a specified number of creator tokens with ETH and sends them to the caller.
  /// @dev Transactions calling this function must include an ETH payment as its `value`. This ETH
  /// is then swapped for the equivalent amount of USDC needed to purchase the Creator Tokens.
  /// @dev Ensure that the ETH `value` sent with the transaction is equal to or greater than
  /// the amount of USDC required for the purchase.
  /// @dev You can get a quote for the amount of ETH you have to pay to get a certain amount of USDC
  /// by calling Uniswap's `QuoterV2` contract off-chain. Check Uniswap docs:
  /// https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and `quote` function
  /// in `test/SwapRouter.fork.8453.t.sol.sol`
  /// @param _creatorToken The address of the creator token to buy.
  /// @param _numOfTokens The number of tokens to buy.
  /// @param _maxPayment The maximum amount of USDC to be paid.
  /// @return _amountOut The amount of USDC paid.
  function bulkBuyWithEth(address _creatorToken, uint256 _numOfTokens, uint256 _maxPayment)
    external
    payable
    returns (uint256 _amountOut)
  {
    _amountOut = bulkBuyWithEth(_creatorToken, msg.sender, _numOfTokens, _maxPayment);
  }

  /// @notice Buys a specified number of creator tokens with ETH and sends them to a specified
  /// address.
  /// @dev Transactions calling this function must include an ETH payment as its `value`. This ETH
  /// is then swapped for the equivalent amount of USDC needed to purchase the Creator Tokens.
  /// @dev Ensure that the ETH `value` sent with the transaction is equal to or greater than
  /// the amount of USDC required for the purchase.
  /// @dev You can get a quote for the amount of ETH you have to pay to get a certain amount of USDC
  /// by calling Uniswap's `QuoterV2` contract off-chain. Check Uniswap docs:
  /// https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and `quote` function
  /// in `test/SwapRouter.fork.8453.t.sol.sol`
  /// @param _creatorToken The address of the creator token to buy.
  /// @param _to The address to send the purchased creator tokens.
  /// @param _numOfTokens The number of tokens to buy.
  /// @param _maxPayment The maximum amount of USDC to be paid.
  /// @return _amountOut The amount of USDC paid.
  function bulkBuyWithEth(
    address _creatorToken,
    address _to,
    uint256 _numOfTokens,
    uint256 _maxPayment
  ) public payable returns (uint256 _amountOut) {
    _swapEthForUSDC(_creatorToken, _numOfTokens, msg.value);
    _approveCreatorToken(_creatorToken, _maxPayment);
    _amountOut = ICreatorToken(_creatorToken).bulkBuy(_to, _numOfTokens, _maxPayment);
  }

  /// @notice Swaps ETH for USDC.
  /// @param _creatorToken The address of the creator token.
  /// @param _numOfTokens The number of tokens to buy.
  /// @param _amountIn The amount of ETH to swap.
  function _swapEthForUSDC(address _creatorToken, uint256 _numOfTokens, uint256 _amountIn) private {
    // // Encoding the inputs for V3_SWAP_EXACT_IN
    bytes[] memory inputs = new bytes[](3);
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) =
      ICreatorToken(_creatorToken).priceToBuyNext(_numOfTokens);
    // Amount of USDC required to purchase `_numOfTokens`
    uint256 _amountOut = _tokenPrice + _creatorFee + _adminFee;
    // WRAP_ETH
    inputs[0] = abi.encode(address(UNIVERSAL_ROUTER), _amountIn);
    // V3_SWAP_EXACT_OUT
    inputs[1] = abi.encode(address(this), _amountOut, _amountIn, path, false);
    // UNWRAP_WETH returns leftover ETH amount to the caller
    inputs[2] = abi.encode(msg.sender, 0);

    // // Execute on the UniversalRouter
    UNIVERSAL_ROUTER.execute{value: _amountIn}(COMMANDS, inputs, block.timestamp + 60);
  }

  /// @dev Approves the creator token contract to transfer USDC from this contract.
  /// @param _creatorToken The address of the creator token.
  /// @param _maxPayment The amount of USDC to be spent.
  function _approveCreatorToken(address _creatorToken, uint256 _maxPayment) private {
    if (IERC20(USDC_ADDRESS).allowance(address(this), address(_creatorToken)) < _maxPayment) {
      IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    }
  }
}
