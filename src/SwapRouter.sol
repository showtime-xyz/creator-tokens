// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniversalRouter} from "src/interfaces/IUniversalRouter.sol";
import {ICreatorToken} from "src/interfaces/ICreatorToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapRouter {
  IUniversalRouter private constant UNIVERSAL_ROUTER =
    IUniversalRouter(0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC); // Base

  address public constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;
  address public constant USDC_ADDRESS = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
  // for WRAP_ETH and V3_SWAP_EXACT_IN
  bytes private path;
  bytes private constant COMMANDS = abi.encodePacked(bytes1(uint8(0x0b)), bytes1(uint8(0x00)));
  bytes3 private constant LOW_FEE_TIER = bytes3(uint24(500));

  constructor() {
    path =
      bytes.concat(bytes20(address(WETH_ADDRESS)), LOW_FEE_TIER, bytes20(address(USDC_ADDRESS)));
  }

  function buyWithEth(address _creatorToken, uint256 _maxPayment) external payable {
    buyWithEth(_creatorToken, msg.sender, _maxPayment);
  }

  function buyWithEth(address _creatorToken, address _to, uint256 _maxPayment) public payable {
    _swapEthForUSDC(_to, msg.value);
    IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    ICreatorToken(_creatorToken).buy(_to, _maxPayment);
  }

  function bulkBuyWithEth(address _creatorToken, uint256 _numOfTokens, uint256 _maxPayment)
    public
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
    _swapEthForUSDC(_to, msg.value);
    IERC20(USDC_ADDRESS).approve(address(_creatorToken), type(uint256).max);
    ICreatorToken(_creatorToken).bulkBuy(_to, _numOfTokens, _maxPayment);
  }

  function _swapEthForUSDC(address _recipient, uint256 _amountIn) private {
    // // Encoding the inputs for V3_SWAP_EXACT_IN
    bytes[] memory inputs = new bytes[](2);
    inputs[0] = abi.encode(address(UNIVERSAL_ROUTER), _amountIn);
    inputs[1] = abi.encode(address(this), _amountIn, 0, path, false);
    // // Execute on the UniversalRouter
    UNIVERSAL_ROUTER.execute{value: _amountIn}(COMMANDS, inputs, block.timestamp + 15);
  }
}
