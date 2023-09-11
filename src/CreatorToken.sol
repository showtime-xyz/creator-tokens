// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract CreatorToken is ERC721 {
  address public creator;
  IERC20 public payToken;

  constructor(string memory _name, string memory _symbol, address _creator, IERC20 _payToken)
    ERC721(_name, _symbol)
  {
    creator = _creator;
    payToken = _payToken;
    _safeMint(_creator, 1);
  }
}
