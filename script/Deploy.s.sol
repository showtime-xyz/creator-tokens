// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CreatorTokenFactory} from "src/CreatorTokenFactory.sol";
import {ITestableShowtimeVerifier} from "test/interfaces/ITestableShowtimeVerifier.sol";

contract Deploy is Script {
  CreatorTokenFactory creatorTokenFactory;
  ITestableShowtimeVerifier verifier;
  bytes32 domainSeparator;

  /// @notice Deploy the contract
  function run(address _verifierAddress) public {
    verifier = ITestableShowtimeVerifier(_verifierAddress);
    if (address(verifier).code.length == 0) revert("Verifier address is not a contract");
    // Setup Domain Separator
    domainSeparator = verifier.domainSeparator();

    // Deploy the contract
    vm.broadcast();

    creatorTokenFactory = new CreatorTokenFactory(verifier, domainSeparator);
    require(creatorTokenFactory.domainSeparator() == domainSeparator, "Domain separator Mismatch");

    console2.log("Deployed contract address %s", address(creatorTokenFactory));
  }
}
