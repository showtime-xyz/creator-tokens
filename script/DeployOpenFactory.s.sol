// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OpenCreatorTokenFactory} from "src/OpenCreatorTokenFactory.sol";

contract Deploy is Script {
  /// @notice Deploy the contract
  function run() public {
    // Deploy the factory contract
    vm.broadcast();
    OpenCreatorTokenFactory openCreatorTokenFactory = new OpenCreatorTokenFactory();

    console2.log("Deployed factory contract address %s", address(openCreatorTokenFactory));
  }
}
