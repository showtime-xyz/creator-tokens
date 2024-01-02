// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken} from "src/CreatorToken.sol";
import {SigmoidBondingCurve} from "src/SigmoidBondingCurve.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {CreatorTokenFactory, Attestation} from "src/CreatorTokenFactory.sol";

contract CreatorTokenFactoryTest is Test {
  CreatorTokenFactory factory;

  uint256 constant MAX_FEE = 2500; // Copied from Creator Token private constant

  event CreatorTokenDeployed(
    CreatorToken indexed creatorToken,
    SigmoidBondingCurve indexed bondingCurve,
    CreatorTokenFactory.DeploymentConfig config
  );

  function setUp() public {
    factory = new CreatorTokenFactory();
  }

  function _assertValidDeployment(
    CreatorTokenFactory.DeploymentConfig memory _config,
    CreatorToken _creatorToken
  ) public {
    assertEq(_creatorToken.name(), _config.name);
    assertEq(_creatorToken.symbol(), _config.symbol);
    assertEq(_creatorToken.tokenURI(0), _config.tokenURI);
    assertEq(_creatorToken.creator(), _config.creator);
    assertEq(_creatorToken.CREATOR_FEE_BIPS(), _config.creatorFee);
    assertEq(_creatorToken.CREATOR_ROYALTY_BIPS(), _config.creatorRoyalty);
    assertEq(_creatorToken.admin(), _config.admin);
    assertEq(_creatorToken.ADMIN_FEE_BIPS(), _config.adminFee);
    assertEq(_creatorToken.REFERRER(), _config.referrer);
    assertEq(address(_creatorToken.payToken()), address(_config.payToken));

    SigmoidBondingCurve _bondingCurve = SigmoidBondingCurve(address(_creatorToken.BONDING_CURVE()));
    assertEq(_bondingCurve.BASE_PRICE(), _config.basePrice);
    assertEq(_bondingCurve.INFLECTION_POINT(), _config.inflectionPoint);
    assertEq(_bondingCurve.INFLECTION_PRICE(), _config.inflectionPrice);
  }
}

contract TokenDeployment is CreatorTokenFactoryTest {
  // Test with a static, realistic config as a sanity check
  function test_DeploysCreatorTokenWithStaticConfig() public {
    CreatorTokenFactory.DeploymentConfig memory _config = CreatorTokenFactory.DeploymentConfig({
      name: "Creator Test Token",
      symbol: "CTT",
      tokenURI: "ipfs://bafybeigwkxrxgqk27netupk5xxxput2fdjnhl4vrgy46nmyqpj4p4jdfsy",
      creator: address(0xace),
      creatorFee: 700,
      creatorRoyalty: 1000,
      admin: address(0xb055),
      adminFee: 300,
      referrer: address(0xd00d),
      payToken: IERC20(address(0xca5)),
      basePrice: 1e6,
      linearPriceSlope: 0.1e6,
      inflectionPrice: 845e6,
      inflectionPoint: 2000
    });

    // hardcoded, pre-calculated addresses for the test config, so we can expect the event emissions
    CreatorToken preCalculatedTokenAddress =
      CreatorToken(0x037eDa3aDB1198021A9b2e88C22B464fD38db3f3);
    SigmoidBondingCurve preCalculatedBondingCurve =
      SigmoidBondingCurve(0x104fBc016F4bb334D775a19E8A6510109AC63E00);

    vm.expectEmit(true, true, true, true);
    emit CreatorTokenDeployed(preCalculatedTokenAddress, preCalculatedBondingCurve, _config);
    CreatorToken _deployedToken = factory.deploy(_config);
    _assertValidDeployment(_config, _deployedToken);
  }

  // Fuzz the attestation and config and deploy
  function test_DeploysCreatorToken(CreatorTokenFactory.DeploymentConfig memory _config) public {
    CreatorToken _deployedToken = factory.deploy(_config);
    _assertValidDeployment(_config, _deployedToken);
  }
}
