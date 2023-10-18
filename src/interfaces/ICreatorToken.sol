// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICreatorToken {
  function buy(uint256 _maxPayment) external returns (uint256 _totalPrice);

  function buy(address _to, uint256 _maxPayment) external returns (uint256 _totalPrice);

  function bulkBuy(uint256 _numOfTokens, uint256 _maxPayment)
    external
    returns (uint256 _totalPrice);

  function bulkBuy(address _to, uint256 _numOfTokens, uint256 _maxPayment)
    external
    returns (uint256 _totalPrice);

  function sell(uint256 _tokenId) external returns (uint256 _netProceeds);

  function sell(uint256 _tokenId, uint256 _minAcceptedPrice)
    external
    returns (uint256 _netProceeds);

  function bulkSell(uint256[] memory _tokenIds) external returns (uint256 _netProceeds);

  function bulkSell(uint256[] memory _tokenIds, uint256 _minAcceptedPrice)
    external
    returns (uint256 _netProceeds);

  function updateCreator(address _newCreator) external;

  function updateAdmin(address _newAdmin) external;

  function tokenURI(uint256) external view returns (string memory);

  function updateTokenURI(string memory _newTokenURI) external;

  function priceToBuyNext()
    external
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee);

  function priceToBuyNext(uint256 _numOfTokens)
    external
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee);
}
