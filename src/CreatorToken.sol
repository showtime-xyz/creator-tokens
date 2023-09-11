// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract CreatorToken is ERC721 {
  using SafeERC20 for IERC20;

  address public creator;
  IERC20 public payToken;

  uint256 private lastId;

  constructor(string memory _name, string memory _symbol, address _creator, IERC20 _payToken)
    ERC721(_name, _symbol)
  {
    creator = _creator;
    payToken = _payToken;
    _mintAndIncrement(_creator);
  }

  function payAndMint(uint256 _maxPayment) public {
    uint256 _mintPrice = _temporaryGetNextTokenPrice();

    // TODO: Validate mint price is less then or equal to max price

    // TODO: Emit minting event that includes receiving address, token Id, AND payment amount for
    // mint

    // TODO: Write a version of this method that takes the _mintTo address (refactor w/ shared
    // internal method)

    _mintAndIncrement(msg.sender);
    payToken.safeTransferFrom(msg.sender, address(this), _mintPrice);
  }

  // Placeholder function for an eventual bonding curve function and/or contract
  function _temporaryGetNextTokenPrice() public pure returns (uint256) {
    return 1e18;
  }

  function _mintAndIncrement(address _to) private {
    lastId += 1;
    _mint(_to, lastId);
  }
}
