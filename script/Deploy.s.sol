// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {CreatorTokenFactory} from "src/CreatorTokenFactory.sol";
import {IShowtimeVerifier} from "src/lib/IShowtimeVerifier.sol";

contract Deploy is Script {
  CreatorTokenFactory creatorTokenFactory;
  uint256 constant EXPECTED_NONCE = 0; // TODO Edit this with the nonce of the deployer address
    // The list of networks to deploy to.
  string[] public networks = ["mainnet", "base"];
  // TODO Edit this with the address of the ShowtimeVerifier contract
  IShowtimeVerifier[] VERIFIERS = [
    // ShowtimeVerifier contract on mainnet
    IShowtimeVerifier(0x481273EB2B6A21e918f6952A6c53C08691FE768F),
    // ShowtimeVerifier contract on base
    IShowtimeVerifier(0x481273EB2B6A21e918f6952A6c53C08691FE768F)
  ];
  // TODO Edit this with the domain separator of the ShowtimeVerifier contract on mainnet
  bytes32 constant MAINNET_DOMAIN_SEPARATORS = "MAINNET_DOMAIN_SEPARATORS";
  // TODO Edit this with the domain separator of the ShowtimeVerifier contract on base
  bytes32 constant BASE_DOMAIN_SEPARATORS = "BASE_DOMAIN_SEPARATORS";
  bytes32[] DOMAIN_SEPARATORS;

  mapping(string => address) public creatorTokenFactoryAddresses;

  /// @notice Deploy the contract to the list of networks,
  function run() public {
    // Setup Domain Separators
    DOMAIN_SEPARATORS[0] = MAINNET_DOMAIN_SEPARATORS;
    DOMAIN_SEPARATORS[1] = BASE_DOMAIN_SEPARATORS;

    if (DOMAIN_SEPARATORS.length != VERIFIERS.length || DOMAIN_SEPARATORS.length != networks.length)
    {
      revert("Check your DOMAIN_SEPARATORS, VERIFIERS, and networks arrays' lengths");
    }

    // Compute the address the contract will be deployed to
    address expectedContractAddress = computeCreateAddress(msg.sender, EXPECTED_NONCE);
    console2.log("Expected contract address: %s", expectedContractAddress);

    // Check if the contract is already deployed on the network, if not, deploy it.
    for (uint256 i; i < networks.length; i++) {
      vm.createSelectFork(getChain(networks[i]).rpcUrl);

      bool isDeployed = address(expectedContractAddress).code.length > 0;
      if (isDeployed) {
        console2.log(
          "Skipping '%s': contract already deployed at %s", networks[i], expectedContractAddress
        );
        revert("Contract already deployed");
      }

      if (address(VERIFIERS[i]).code.length == 0) revert("Verifier address is not a contract");

      uint256 nonce = vm.getNonce(msg.sender);
      if (nonce != EXPECTED_NONCE) {
        console2.log(
          "%s: current nonce %d != expected nonce %d", networks[i], nonce, EXPECTED_NONCE
        );
        revert("Nonce Mismatch");
      }

      // Deploy the contract
      vm.broadcast();

      creatorTokenFactory = new CreatorTokenFactory(VERIFIERS[i], DOMAIN_SEPARATORS[i]);
      require(address(creatorTokenFactory) == expectedContractAddress, "Deploy failed");
      require(
        creatorTokenFactory.domainSeparator() == DOMAIN_SEPARATORS[i], "Domain separator Mismatch"
      );
      creatorTokenFactoryAddresses[networks[i]] = address(creatorTokenFactory);
    }

    for (uint256 i; i < networks.length; i++) {
      console2.log(
        "Deployed contract to '%s' at %s", networks[i], creatorTokenFactoryAddresses[networks[i]]
      );
    }
  }
}
