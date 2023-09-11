// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";

contract Deploy is Script {

  function run() public {
    vm.broadcast();
  }
}
