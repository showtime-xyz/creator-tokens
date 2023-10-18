// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "openzeppelin/token/ERC721/extensions/ERC721Royalty.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IBondingCurve} from "src/interfaces/IBondingCurve.sol";

/// @title CreatorToken
/// @notice A token contract where creators can mint and sell tokens according to a price determined
/// by a bonding curve.
/// Key Features:
///   - Royalty System: Supports the ERC-2981 royalty standard, allowing creators to receive a
/// percentage of secondary sales.
///   - Dynamic Pricing: Prices for buying or selling tokens are determined by an integrated
/// bonding curve.
///   - Referral System: Has a built-in referral mechanism to mint a token for the referrer at
/// deployment.
///   - Fee Mechanism: Defines separate fees for both the creator and an admin, which are taken
/// from primary and secondary sales.
/// @dev This contract supports ERC-2981 royalty standard.
contract CreatorToken is ERC721Royalty {
  using SafeERC20 for IERC20;

  error CreatorToken__MaxFeeExceeded(uint256 fee, uint256 maxFee);
  error CreatorToken__MaxPaymentExceeded(uint256 price, uint256 maxPayment);
  error CreatorToken__Unauthorized(bytes32 reason, address caller);
  error CreatorToken__AddressZeroNotAllowed();
  error CreatorToken__CallerIsNotOwner(uint256 tokenId, address owner, address caller);
  error CreatorToken__MinAcceptedPriceExceeded(uint256 price, uint256 minAcceptedPrice);
  error CreatorToken__LastTokensCannotBeSold(uint256 circulatingSupply);
  error CreatorToken__MinHoldingTimeNotReached(uint256 holdingTime, uint256 minHoldingTime);
  error CreatorToken__ContractIsPaused();

  /// @notice ID of the last token minted.
  uint256 public lastId;
  /// @notice Total supply of the creator tokens.
  uint256 public totalSupply;
  /// @notice Address of the creator of the creator token.
  address public creator;
  /// @notice Address of the admin of the creator token.
  address public admin;
  /// @notice Address of the referrer, if any.
  address public immutable REFERRER;
  /// @notice State indicating whether the contract is paused.
  bool public isPaused;
  /// @notice URI pointing to the metadata for the creator token.
  string private creatorTokenURI;
  /// @notice ERC20 token used for payments in the contract.
  IERC20 public payToken;
  /// @notice Bonding curve contract used to determine token prices.
  IBondingCurve public immutable BONDING_CURVE;

  /// @notice Constant to represent percentages in basis points.
  uint256 constant BIP = 10_000;
  /// @notice Creator fee taken as a percentage when tokens are bought, in basis points.
  uint256 public immutable CREATOR_FEE_BIPS;
  /// @notice Royalty fee for the creator, in basis points.
  uint96 public immutable CREATOR_ROYALTY_BIPS;
  /// @notice Admin fee taken for the admin as a percentage, in basis points.
  uint256 public immutable ADMIN_FEE_BIPS;
  /// @notice Maximum allowed fee in basis points.
  uint256 private constant MAX_FEE = 2500; // 25% in bips
  /// @notice Minimum time a user must hold a token before selling, in blocks.
  uint256 private constant MIN_HOLDING_TIME = 60;
  /// @notice Mapping to track purchase time of tokens.
  mapping(uint256 tokenId => uint256 blockTimestamp) internal purchaseTime;

  /// @notice Event emitted when a new token is bought.
  /// @param payer Address that paid for the token.
  /// @param receiver Address that received the token.
  /// @param tokenId ID of the token.
  /// @param paymentAmount Amount of USDC paid for the token excluding fees.
  /// @param creatorFee Amount of USDC paid to the creator.
  /// @param adminFee Amount of USDC paid to the admin.
  event Bought( // the address that paid for the token
    address indexed payer,
    address indexed receiver,
    uint256 indexed tokenId,
    uint256 paymentAmount,
    uint256 creatorFee,
    uint256 adminFee
  );

  /// @notice Event emitted when a token is sold.
  /// @param seller Address that sold the token.
  /// @param tokenId ID of the token.
  /// @param salePrice Amount of USDC received for the token excluding fees.
  /// @param creatorFee Amount of USDC paid to the creator.
  /// @param adminFee Amount of USDC paid to the admin.
  event Sold(
    address indexed seller,
    uint256 indexed tokenId,
    uint256 salePrice,
    uint256 creatorFee,
    uint256 adminFee
  );

  /// @notice Event emitted when the contract pause state is toggled.
  event ToggledPause(bool oldPauseState, bool newPauseState, address caller);

  /// @notice Event emitted when the creator is updated.
  event CreatorUpdated(address oldCreator, address newCreator);

  /// @notice Event emitted when the admin is updated.
  event AdminUpdated(address oldAdmin, address newAdmin);

  /// @notice Event emitted when the tokenURI is updated.
  event TokenURIUpdated(string oldTokenURI, string newTokenURI);

  /// @notice Ensures that the given address is not the zero address.
  modifier isNotAddressZero(address _address) {
    if (_address == address(0)) revert CreatorToken__AddressZeroNotAllowed();
    _;
  }

  /// @notice Ensures that the caller is either the creator or the admin.
  modifier onlyCreatorOrAdmin(address _caller) {
    if (_caller != creator && _caller != admin) {
      revert CreatorToken__Unauthorized("not creator or admin", _caller);
    }
    _;
  }

  /// @notice Ensures that the contract is not in a paused state.
  modifier whenNotPaused() {
    if (isPaused) revert CreatorToken__ContractIsPaused();
    _;
  }

  /// @notice Initializes a new CreatorToken contract.
  /// @dev Sets initial values for URI, fees, and initializes the ERC721 contract.
  /// @param _name The name of the ERC721 token.
  /// @param _symbol The symbol of the ERC721 token.
  /// @param _tokenURI The URI for the creator token.
  /// @param _creator Address of the creator.
  /// @param _creatorFee Creator fee in BIPs.
  /// @param _creatorRoyalty Creator royalty fee in BIPs.
  /// @param _admin Address of the admin.
  /// @param _adminFee Admin fee in BIPs.
  /// @param _referrer Address of the referrer.
  /// @param _payToken ERC20 token used for payments.
  /// @param _bondingCurve The bonding curve contract for token pricing.
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _tokenURI,
    address _creator,
    uint256 _creatorFee,
    uint96 _creatorRoyalty,
    address _admin,
    uint256 _adminFee,
    address _referrer,
    IERC20 _payToken,
    IBondingCurve _bondingCurve
  ) ERC721(_name, _symbol) isNotAddressZero(_creator) isNotAddressZero(_admin) {
    if (_creatorFee > MAX_FEE) revert CreatorToken__MaxFeeExceeded(_creatorFee, MAX_FEE);
    if (_creatorRoyalty > MAX_FEE) revert CreatorToken__MaxFeeExceeded(_creatorRoyalty, MAX_FEE);
    if (_adminFee > MAX_FEE) revert CreatorToken__MaxFeeExceeded(_adminFee, MAX_FEE);

    creatorTokenURI = _tokenURI;
    creator = _creator;
    CREATOR_FEE_BIPS = _creatorFee;
    CREATOR_ROYALTY_BIPS = _creatorRoyalty;
    _setDefaultRoyalty(address(_creator), _creatorRoyalty);
    admin = _admin;
    ADMIN_FEE_BIPS = _adminFee;
    REFERRER = _referrer;
    payToken = _payToken;
    BONDING_CURVE = _bondingCurve;
    _mintAndIncrement(_creator);

    if (_referrer != address(0)) _mintAndIncrement(_referrer);
  }

  /// @notice Purchase a token.
  /// @dev Reverts if the total price exceeds `_maxPayment`.
  /// @param _maxPayment The maximum amount of USDC the buyer is willing to pay.
  /// @return _totalPrice The total amount of USDC paid for the creator token.
  function buy(uint256 _maxPayment) public returns (uint256 _totalPrice) {
    _totalPrice = buy(msg.sender, _maxPayment);
  }

  /// @notice Purchase a token and mint to another address.
  /// @dev Reverts if the total price exceeds `_maxPayment`.
  /// @param _to Address to receive the token.
  /// @param _maxPayment The maximum amount of USDC the buyer is willing to pay.
  /// @return _totalPrice The total amount of USDC paid for the creator token.
  function buy(address _to, uint256 _maxPayment) public returns (uint256 _totalPrice) {
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = _buyWithoutPayment(_to);
    _totalPrice = _tokenPrice + _creatorFee + _adminFee;

    if (_totalPrice > _maxPayment) {
      revert CreatorToken__MaxPaymentExceeded(_totalPrice, _maxPayment);
    }

    payToken.safeTransferFrom(msg.sender, address(this), _tokenPrice);
    payToken.safeTransferFrom(msg.sender, creator, _creatorFee);
    payToken.safeTransferFrom(msg.sender, admin, _adminFee);
  }

  /// @notice Buy multiple creator tokens in bulk and mint them to the caller.
  /// @dev The recipient of the creator tokens is the msg.sender.
  /// @param _numOfTokens Number of tokens to buy.
  /// @param _maxPayment The maximum amount of USDC the caller is willing to pay.
  /// @return _totalPrice The total amount of USDC paid for the creator tokens including fees.
  function bulkBuy(uint256 _numOfTokens, uint256 _maxPayment) public returns (uint256 _totalPrice) {
    _totalPrice = bulkBuy(msg.sender, _numOfTokens, _maxPayment);
  }

  /// @notice Buy multiple tokens in bulk and mint them to a specified address.
  /// @param _to Address where the tokens should be sent.
  /// @param _numOfTokens Number of tokens to buy.
  /// @param _maxPayment The maximum amount of USDC the caller is willing to pay.
  /// @return _totalPrice The total amount of USDC paid for the creator tokens including fees.
  function bulkBuy(address _to, uint256 _numOfTokens, uint256 _maxPayment)
    public
    returns (uint256 _totalPrice)
  {
    // variables for tracking the total amounts across purchases
    uint256 _totalTokenPrice;
    uint256 _totalCreatorFee;
    uint256 _totalAdminFee;

    // variables to hold per-token prices for each iteration
    uint256 _tokenPrice;
    uint256 _creatorFee;
    uint256 _adminFee;

    for (uint256 _i = 0; _i < _numOfTokens; _i++) {
      (_tokenPrice, _creatorFee, _adminFee) = _buyWithoutPayment(_to);
      _totalTokenPrice += _tokenPrice;
      _totalCreatorFee += _creatorFee;
      _totalAdminFee += _adminFee;
    }

    _totalPrice = _totalTokenPrice + _totalCreatorFee + _totalAdminFee;

    if (_totalPrice > _maxPayment) {
      revert CreatorToken__MaxPaymentExceeded(_totalPrice, _maxPayment);
    }

    payToken.safeTransferFrom(msg.sender, address(this), _totalTokenPrice);
    payToken.safeTransferFrom(msg.sender, creator, _totalCreatorFee);
    payToken.safeTransferFrom(msg.sender, admin, _totalAdminFee);
  }

  /// @notice Sell a token.
  /// @dev Sets the minimum accepted proceeds to 0.
  /// @param _tokenId ID of the token to be sold.
  /// @return _netProceeds The net proceeds from the sale in USDC after fees.
  function sell(uint256 _tokenId) public returns (uint256 _netProceeds) {
    _netProceeds = sell(_tokenId, 0);
  }

  /// @notice Sell a token with a minimum accepted price.
  /// @param _tokenId ID of the token to be sold.
  /// @param _minAcceptedPrice The minimum proceed in USDC the seller is willing to accept.
  /// @return _netProceeds The net proceeds in USDC from the sale after fees.
  function sell(uint256 _tokenId, uint256 _minAcceptedPrice) public returns (uint256 _netProceeds) {
    uint256 _creatorFee;
    uint256 _adminFee;

    (_netProceeds, _creatorFee, _adminFee) = _sellWithoutPayment(_tokenId);

    if (_netProceeds < _minAcceptedPrice) {
      revert CreatorToken__MinAcceptedPriceExceeded(_netProceeds, _minAcceptedPrice);
    }

    payToken.safeTransfer(msg.sender, _netProceeds);
    payToken.safeTransfer(creator, _creatorFee);
    payToken.safeTransfer(admin, _adminFee);
  }

  /// @notice Sell multiple tokens in bulk.
  /// @dev Sets the minimum accepted proceeds to 0.
  /// @param _tokenIds Array of token IDs to be sold.
  /// @return _netProceeds The total net proceeds in USDC from the bulk sale.
  function bulkSell(uint256[] memory _tokenIds) public returns (uint256 _netProceeds) {
    _netProceeds = bulkSell(_tokenIds, 0);
  }

  /// @notice Sell multiple tokens with a minimum accepted proceeds in USDC for the total sale.
  /// @param _tokenIds Array of token IDs to be sold.
  /// @param _minAcceptedPrice The minimum total net proceeds in USDC the seller is willing to
  /// accept for the bulk sale.
  /// @return _netProceeds The total net proceeds from the bulk sale.
  function bulkSell(uint256[] memory _tokenIds, uint256 _minAcceptedPrice)
    public
    returns (uint256 _netProceeds)
  {
    uint256 _totalNetProceeds;
    uint256 _totalCreatorFee;
    uint256 _totalAdminFee;

    uint256 _creatorFee;
    uint256 _adminFee;

    for (uint256 _i = 0; _i < _tokenIds.length; _i++) {
      (_netProceeds, _creatorFee, _adminFee) = _sellWithoutPayment(_tokenIds[_i]);

      _totalNetProceeds += _netProceeds;
      _totalCreatorFee += _creatorFee;
      _totalAdminFee += _adminFee;
    }

    _netProceeds = _totalNetProceeds;

    if (_netProceeds < _minAcceptedPrice) {
      revert CreatorToken__MinAcceptedPriceExceeded(_netProceeds, _minAcceptedPrice);
    }

    payToken.safeTransfer(msg.sender, _netProceeds);
    payToken.safeTransfer(creator, _totalCreatorFee);
    payToken.safeTransfer(admin, _totalAdminFee);
  }

  /// @notice Updates the creator of the contract.
  /// @dev Only the current creator can update the creator address.
  /// @param _newCreator Address of the new creator.
  function updateCreator(address _newCreator) public isNotAddressZero(_newCreator) {
    if (msg.sender != creator) revert CreatorToken__Unauthorized("not creator", msg.sender);
    creator = _newCreator;
    _setDefaultRoyalty(address(_newCreator), uint96(CREATOR_ROYALTY_BIPS));
    emit CreatorUpdated(msg.sender, _newCreator);
  }

  /// @notice Updates the admin of the contract.
  /// @dev Only the current admin can update the admin address.
  /// @param _newAdmin Address of the new admin.
  function updateAdmin(address _newAdmin) public isNotAddressZero(_newAdmin) {
    if (msg.sender != admin) revert CreatorToken__Unauthorized("not admin", msg.sender);
    admin = _newAdmin;
    emit AdminUpdated(msg.sender, _newAdmin);
  }

  /// @notice Retrieves the URI of the token.
  /// @dev This function overrides the `tokenURI` function from ERC-721 standard.
  /// @return URI of the token.
  function tokenURI(uint256) public view override returns (string memory) {
    return creatorTokenURI;
  }

  /// @notice Updates the URI of the token.
  /// @dev Only the creator or admin can update the token URI.
  /// @param _newTokenURI New URI for the token.
  function updateTokenURI(string memory _newTokenURI) public onlyCreatorOrAdmin(msg.sender) {
    emit TokenURIUpdated(creatorTokenURI, _newTokenURI);
    creatorTokenURI = _newTokenURI;
  }

  /// @notice Handles the internal minting logic for a token without payment.
  /// @dev The function mints and transfers a token.
  /// @param _to Address where the new creator token should be sent.
  /// @return _tokenPrice The price of the token in USDC.
  /// @return _creatorFee The creator's fee in USDC.
  /// @return _adminFee The admin's fee in USDC.
  function _buyWithoutPayment(address _to)
    internal
    whenNotPaused
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    (_tokenPrice, _creatorFee, _adminFee) = priceToBuyNext();

    _mintAndIncrement(_to);
    purchaseTime[lastId] = block.timestamp;
    emit Bought(msg.sender, _to, lastId, _tokenPrice, _creatorFee, _adminFee);
  }

  /// @notice Handles the internal burn logic for a token without payment.
  /// @dev The function transfers and burns a token.
  /// @param _tokenId ID of the token to be sold.
  /// @return _netProceeds The net proceeds from the sale after deducting fees.
  /// @return _creatorFee The creator's fee in USDC.
  /// @return _adminFee The admin's fee in USDC.
  function _sellWithoutPayment(uint256 _tokenId)
    internal
    whenNotPaused
    returns (uint256 _netProceeds, uint256 _creatorFee, uint256 _adminFee)
  {
    if (msg.sender != ownerOf(_tokenId)) {
      revert CreatorToken__CallerIsNotOwner(_tokenId, ownerOf(_tokenId), msg.sender);
    }
    if (block.timestamp - purchaseTime[_tokenId] < MIN_HOLDING_TIME) {
      revert CreatorToken__MinHoldingTimeNotReached(
        block.timestamp - purchaseTime[_tokenId], MIN_HOLDING_TIME
      );
    }

    bool _isOneOfLastTokens =
      (REFERRER == address(0) && totalSupply == 1) || (REFERRER != address(0) && totalSupply == 2);
    if (_isOneOfLastTokens) revert CreatorToken__LastTokensCannotBeSold(totalSupply);

    uint256 _tokenPrice;
    (_tokenPrice, _creatorFee, _adminFee) = priceToSellNext();
    _netProceeds = _tokenPrice - _creatorFee - _adminFee;

    transferFrom(msg.sender, address(this), _tokenId);
    _burnAndDecrement(_tokenId);
    emit Sold(msg.sender, _tokenId, _tokenPrice, _creatorFee, _adminFee);
  }

  /// @notice Set a new pause state for the contract.
  /// @dev Only the creator or admin can pause/unpause the contract.
  /// @param _pauseState The desired paused state: true to pause, false to unpause.
  function pause(bool _pauseState) public onlyCreatorOrAdmin(msg.sender) {
    emit ToggledPause(isPaused, _pauseState, msg.sender);
    isPaused = _pauseState;
  }

  /// @notice Retrieves the price for the next token to be bought in USDC.
  /// @return _tokenPrice The price for the next token in USDC.
  /// @return _creatorFee The creator's fee for the next token in USDC.
  /// @return _adminFee The admin's fee for the next token in USDC.
  function priceToBuyNext()
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    _tokenPrice = BONDING_CURVE.priceForTokenNumber((totalSupply + 1) - _preMintOffset());
    (_creatorFee, _adminFee) = calculateFees(_tokenPrice);
  }

  /// @notice Calculates the aggregated price for the next N tokens to be bought in USDC.
  /// @param _numOfTokens The number of tokens to calculate the price for.
  /// @return _tokenPrice The aggregated price for the next N tokens in USDC.
  /// @return _creatorFee The aggregated creator's fee for the next N tokens in USDC.
  /// @return _adminFee The aggregated admin's fee for the next N tokens in USDC.
  function priceToBuyNext(uint256 _numOfTokens)
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    // For any given iteration of the loop below, the token number to ask the bonding curve
    // the price of is the current supply, plus the index, plus 1 (because of 0 indexing),
    // minus the pre-mint offset. Here we pre-calculate all those terms except the index, then
    // use this offset below in the loop.
    uint256 _offset = totalSupply + 1 - _preMintOffset();

    // Variables that will hold the price + fees for each iteration of the loop. We must
    // hold each individually to avoid rounding differences that occur if you first find
    // the total price of all tokens, then calculate net fees.
    uint256 _nthTokenPrice;
    uint256 _nthCreatorFee;
    uint256 _nthAdminFee;

    for (uint256 _i = 0; _i < _numOfTokens; _i++) {
      _nthTokenPrice = BONDING_CURVE.priceForTokenNumber(_i + _offset);
      (_nthCreatorFee, _nthAdminFee) = calculateFees(_nthTokenPrice);

      _tokenPrice += _nthTokenPrice;
      _creatorFee += _nthCreatorFee;
      _adminFee += _nthAdminFee;
    }
  }

  /// @notice Retrieves the selling price for the next token to be sold in USDC.
  /// @return _tokenPrice The selling price for the next token in USDC.
  /// @return _creatorFee The creator's fee for the next token in USDC.
  /// @return _adminFee The admin's fee for the next token in USDC.
  function priceToSellNext()
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    _tokenPrice = BONDING_CURVE.priceForTokenNumber(totalSupply - _preMintOffset());
    (_creatorFee, _adminFee) = calculateFees(_tokenPrice);
  }

  /// @notice Calculates the aggregated selling price for the next N tokens to be sold in USDC.
  /// @param _numOfTokens The number of tokens to calculate the selling price for.
  /// @return _tokenPrice The aggregated selling price for the next N tokens in USDC.
  /// @return _creatorFee The aggregated creator's fee for the next N tokens in USDC.
  /// @return _adminFee The aggregated admin's fee for the next N tokens in USDC.
  function priceToSellNext(uint256 _numOfTokens)
    public
    view
    returns (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee)
  {
    uint256 _offset = totalSupply - _preMintOffset();

    uint256 _nthTokenPrice;
    uint256 _nthCreatorFee;
    uint256 _nthAdminFee;

    for (uint256 _i = 0; _i < _numOfTokens; _i++) {
      _nthTokenPrice = BONDING_CURVE.priceForTokenNumber(_offset - _i);
      (_nthCreatorFee, _nthAdminFee) = calculateFees(_nthTokenPrice);

      _tokenPrice += _nthTokenPrice;
      _creatorFee += _nthCreatorFee;
      _adminFee += _nthAdminFee;
    }
  }

  /// @notice Calculates the creator and admin fees in USDC based on a given price in USDC.
  /// @param _price The base price in USDC to calculate fees from.
  /// @return _creatorFee The fee owed to the creator in USDC.
  /// @return _adminFee The fee owed to the admin in USDC.
  function calculateFees(uint256 _price)
    public
    view
    returns (uint256 _creatorFee, uint256 _adminFee)
  {
    _creatorFee = (_price * CREATOR_FEE_BIPS) / BIP;
    _adminFee = (_price * ADMIN_FEE_BIPS) / BIP;
  }

  /// @notice Determines the pre-mint offset based on whether a referrer is set.
  /// @dev If the REFERRER address is zero, the offset is 1; otherwise, it's 2.
  /// @return _offset The determined pre-mint offset.
  function _preMintOffset() private view returns (uint256 _offset) {
    _offset = REFERRER == address(0) ? 1 : 2;
  }

  /// @notice Mints a new token to the specified address and increments the lastId and totalSupply.
  /// @dev Internal function to for minting logic and tracking.
  /// @param _to Address to which the new token will be minted.
  function _mintAndIncrement(address _to) private {
    lastId += 1;
    _mint(_to, lastId);
    totalSupply += 1;
  }

  /// @notice Burns the specified token and decrements the totalSupply counter.
  /// @dev Internal function for burn logic and tracking.
  /// @param _tokenId The ID of the token to be burned.
  function _burnAndDecrement(uint256 _tokenId) private {
    _burn(_tokenId);
    totalSupply -= 1;
  }
}
