// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken} from "src/CreatorToken.sol";

contract CreatorTokenTest is Test {

  CreatorToken public creatorToken;

  function setUp() public {
    creatorToken = new CreatorToken();
  }
}

contract Deployment is CreatorTokenTest {
  function test_TokenIsConfiguredAtDeployment() public {

  }
}
