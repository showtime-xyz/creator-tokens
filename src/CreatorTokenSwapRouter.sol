// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniversalRouter} from "src/lib/IUniversalRouter.sol";
import {ICreatorToken} from "src/interfaces/ICreatorToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract CreatorTokenSwapRouter {
  IUniversalRouter private immutable UNIVERSAL_ROUTER;
  address public immutable WETH_ADDRESS;
  address public immutable USDC_ADDRESS;

  // for WRAP_ETH, V3_SWAP_EXACT_OUT, and UNWRAP_WETH
  bytes private constant COMMANDS =
    abi.encodePacked(bytes1(uint8(0x0b)), bytes1(uint8(0x01)), bytes1(uint8(0x0c)));
  bytes3 private constant LOW_FEE_TIER = bytes3(uint24(500));

  // WETH -> USDC, order is switched because of V3_SWAP_EXACT_OUT
  bytes private path;

  constructor(address _universalRouter, address _wethAddress, address _usdcAddress) {
    UNIVERSAL_ROUTER = IUniversalRouter(_universalRouter);
    WETH_ADDRESS = _wethAddress;
    USDC_ADDRESS = _usdcAddress;
    path =
      bytes.concat(bytes20(address(USDC_ADDRESS)), LOW_FEE_TIER, bytes20(address(WETH_ADDRESS)));
  }

  // You can get a quote for the amount of ETH you have to pay to buy a creator token by calling
  // Uniswap's `QuoterV2` contract off-chain.
  // Check Uniswap docs: https://docs.uniswap.org/contracts/v3/reference/periphery/lens/QuoterV2 and
  // `quote` function in `test/SwapRouter.fork.8453.t.sol.sol`
  function buyWithEth(address _creatorToken, uint256 _maxPayment)
    external
    payable
    returns (uint256 _amountOut)
  {
    _amountOut = buyWithEth(_creatorToken, msg.sender, _maxPayment);
  }

  function buyWithEth(address _creatorToken, address _to, uint256 _maxPayment)
    public
    payable
    returns (uint256 _amountOut)
  {
    _swapEthForUSDC(_creatorToken, 1, msg.value);
    _approveCreatorToken(_creatorToken, _maxPayment);
    _amountOut = ICreatorToken(_creatorToken).buy(_to, _maxPayment);
  }

  function bulkBuyWithEth(address _creatorToken, uint256 _numOfTokens, uint256 _maxPayment)
    external
    payable
    returns (uint256 _amountOut)
  {
    _amountOut = bulkBuyWithEth(_creatorToken, msg.sender, _numOfTokens, _maxPayment);
  }

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

  function _swapEthForUSDC(address _creatorToken, uint256 _numOfTokens, uint256 _amountIn) private {
    // // Encoding the inputs for V3_SWAP_EXACT_IN
    bytes[] memory inputs = new bytes[](3);
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) =
      ICreatorToken(_creatorToken).priceToBuyNext(_numOfTokens);
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

  function _approveCreatorToken(address _creatorToken, uint256 _maxPayment) private {
    if (IERC20(USDC_ADDRESS).allowance(address(this), address(_creatorToken)) < _maxPayment) {
      IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    }
  }
}
