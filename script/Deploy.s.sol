// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CreatorTokenFactory} from "src/CreatorTokenFactory.sol";
import {ITestableShowtimeVerifier} from "test/interfaces/ITestableShowtimeVerifier.sol";
import {CreatorTokenSwapRouter} from "src/CreatorTokenSwapRouter.sol";

contract Deploy is Script {
  /// @notice Deploy the contract
  function run(address _verifierAddress) public {
    ITestableShowtimeVerifier _verifier = ITestableShowtimeVerifier(_verifierAddress);
    if (address(_verifier).code.length == 0) revert("Verifier address is not a contract");
    // Setup Domain Separator
    bytes32 _domainSeparator = _verifier.domainSeparator();

    // Deploy the contract
    vm.broadcast();

    CreatorTokenFactory creatorTokenFactory = new CreatorTokenFactory(_verifier, _domainSeparator);
    require(creatorTokenFactory.domainSeparator() == _domainSeparator, "Domain separator Mismatch");

    console2.log("Deployed contract address %s", address(creatorTokenFactory));
  }

  function deployCreatorTokenSwapRouter(
    address _universalRouter,
    address _wethAddress,
    address _usdcAddress
  ) public {
    vm.broadcast();

    CreatorTokenSwapRouter creatorTokenSwapRouter =
      new CreatorTokenSwapRouter(_universalRouter, _wethAddress, _usdcAddress);
    console2.log("Deployed contract address %s", address(creatorTokenSwapRouter));
  }
}
