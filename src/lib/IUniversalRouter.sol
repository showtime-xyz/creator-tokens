// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

/// @dev Original interface:
/// https://github.com/Uniswap/universal-router/blob/main/contracts/interfaces/IUniversalRouter.sol
interface IUniversalRouter {
  /// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
  /// @param commands A set of concatenated commands, each 1 byte in length
  /// @param inputs An array of byte strings containing abi encoded inputs for each command
  /// @param deadline The deadline by which the transaction must be executed
  function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
    external
    payable;
}
