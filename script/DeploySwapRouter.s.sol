// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CreatorTokenSwapRouterDegen} from "src/CreatorTokenSwapRouterDegen.sol";

contract DeploySwapRouter is Script {
  /// @notice Deploy the contract
  function run() public {
    // Base mainnet addresses
    address universalRouterAddress = 0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC;
    address wethAddress = 0x4200000000000000000000000000000000000006;
    address degenAddress = 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed;

    // Deploy the swap router contract
    vm.broadcast();
    CreatorTokenSwapRouterDegen creatorTokenSwapRouter =
      new CreatorTokenSwapRouterDegen(universalRouterAddress, wethAddress, degenAddress);

    console2.log("Deployed router contract address %s", address(creatorTokenSwapRouter));
  }
}
