// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniversalRouter} from "src/interfaces/IUniversalRouter.sol";
import {ICreatorToken} from "src/interfaces/ICreatorToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract SwapRouter {
  IUniversalRouter private constant UNIVERSAL_ROUTER =
    IUniversalRouter(0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC); // Base

  address public constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
  address public constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  bytes private path;
  // for WRAP_ETH, V3_SWAP_EXACT_OUT, and UNWRAP_WETH
  bytes private constant COMMANDS =
    abi.encodePacked(bytes1(uint8(0x0b)), bytes1(uint8(0x01)), bytes1(uint8(0x0c)));
  bytes3 private constant LOW_FEE_TIER = bytes3(uint24(500));

  constructor() {
    // WETH -> USDC, order is switched because of V3_SWAP_EXACT_OUT
    path =
      bytes.concat(bytes20(address(USDC_ADDRESS)), LOW_FEE_TIER, bytes20(address(WETH_ADDRESS)));
  }

  // You can get a quote for the amount of ETH you have to pay to buy a creator token by calling
  // Uniswap's `QuoterV2` contract off-chain.
  // Check Uniswap docs: https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and
  // `quote` function in `test/SwapRouter.fork.8453.t.sol.sol`
  function buyWithEth(address _creatorToken, uint256 _maxPayment) external payable {
    buyWithEth(_creatorToken, msg.sender, _maxPayment);
  }

  function buyWithEth(address _creatorToken, address _to, uint256 _maxPayment) public payable {
    _swapEthForUSDC(_creatorToken, msg.sender, 1, msg.value);
    IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    ICreatorToken(_creatorToken).buy(_to, _maxPayment);
  }

  function bulkBuyWithEth(address _creatorToken, uint256 _numOfTokens, uint256 _maxPayment)
    external
    payable
  {
    bulkBuyWithEth(_creatorToken, msg.sender, _numOfTokens, _maxPayment);
  }

  function bulkBuyWithEth(
    address _creatorToken,
    address _to,
    uint256 _numOfTokens,
    uint256 _maxPayment
  ) public payable {
    _swapEthForUSDC(_creatorToken, _to, _numOfTokens, msg.value);
    IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    ICreatorToken(_creatorToken).bulkBuy(_to, _numOfTokens, _maxPayment);
  }

  function _swapEthForUSDC(
    address _creatorToken,
    address _recipient,
    uint256 _numOfTokens,
    uint256 _amountIn
  ) private {
    // // Encoding the inputs for V3_SWAP_EXACT_IN
    bytes[] memory inputs = new bytes[](3);
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) =
      ICreatorToken(_creatorToken).priceToBuyNext(_numOfTokens);
    uint256 _amountOut = _tokenPrice + _creatorFee + _adminFee;
    // WRAP_ETH
    inputs[0] = abi.encode(address(UNIVERSAL_ROUTER), _amountIn);
    // V3_SWAP_EXACT_OUT
    inputs[1] = abi.encode(address(this), _amountOut, _amountIn, path, false);
    // UNWRAP_WETH
    inputs[2] = abi.encode(address(_recipient), 0);

    // // Execute on the UniversalRouter
    UNIVERSAL_ROUTER.execute{value: _amountIn}(COMMANDS, inputs, block.timestamp + 60);
  }
}
