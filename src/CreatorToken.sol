// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

contract CreatorToken is ERC721 {
  address public creator;

  constructor(string memory _name, string memory _symbol, address _creator) ERC721(_name, _symbol) {
    creator = _creator;
    _safeMint(_creator, 1);
  }
}
