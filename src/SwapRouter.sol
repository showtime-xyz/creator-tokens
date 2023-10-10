// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUniversalRouter} from "universal-router/interfaces/IUniversalRouter.sol";

contract SwapRouter {
  IUniversalRouter private constant universalRouter =
    IUniversalRouter(0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC); // Base

  // for WRAP_ETH and V3_SWAP_EXACT_IN
  bytes private path;
  bytes private constant commands = abi.encodePacked(bytes1(uint8(0x0b)), bytes1(uint8(0x00)));
  bytes3 private constant LOW_FEE_TIER = bytes3(uint24(500));

  function buyWithEth(address _creatorToken, address _to, uint256 _maxPayment) external payable {
    _swapEthForUSDC(address(this), msg.value);
  }

  function _swapEthForUSDC(address _recipient, uint256 _amountIn) private {
    // // Encoding the inputs for V3_SWAP_EXACT_IN
    bytes[] memory inputs = new bytes[](2);
    inputs[0] = abi.encode(universalRouter, _amountIn);
    inputs[1] = abi.encode(_recipient, _amountIn, 0, path, false);

    (bool success,) = address(universalRouter).call{value: _amountIn}("");
    require(success, "Failed to send Ether");
    // // Execute on the UniversalRouter
    universalRouter.execute(commands, inputs, block.timestamp + 15);
  }
}
