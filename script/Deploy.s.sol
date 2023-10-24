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
  function run(
    address _verifierAddress,
    address _universalRouterAddress,
    address _wethAddress,
    address _usdcAddress
  ) public {
    ITestableShowtimeVerifier _verifier = ITestableShowtimeVerifier(_verifierAddress);
    if (address(_verifier).code.length == 0) revert("Verifier address is not a contract");
    // Setup Domain Separator
    bytes32 _domainSeparator = _verifier.domainSeparator();

    // Deploy the factory contract
    vm.broadcast();
    CreatorTokenFactory creatorTokenFactory = new CreatorTokenFactory(_verifier, _domainSeparator);

    require(creatorTokenFactory.domainSeparator() == _domainSeparator, "Domain separator Mismatch");

    // Deploy the swap router contract
    vm.broadcast();
    CreatorTokenSwapRouter creatorTokenSwapRouter =
      new CreatorTokenSwapRouter(_universalRouterAddress, _wethAddress, _usdcAddress);

    console2.log("Deployed factory contract address %s", address(creatorTokenFactory));
    console2.log("Deployed router contract address %s", address(creatorTokenSwapRouter));
  }
}
