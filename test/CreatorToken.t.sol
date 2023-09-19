// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CreatorToken, IBondingCurve} from "src/CreatorToken.sol";
import {IERC20, ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {MockIncrementingBondingCurve} from "test/mocks/MockIncrementingBondingCurve.sol";

contract CreatorTokenTest is Test {
  IERC20 public payToken;
  IBondingCurve public bondingCurve;
  CreatorToken public creatorToken;
  address public creator = address(0xc2ea702);
  address public admin = address(0xb055);

  string CREATOR_TOKEN_NAME = "Test Token";
  string CREATOR_TOKEN_SYMBOL = "TEST";

  string PAY_TOKEN_NAME = "Payment Token";
  string PAY_TOKEN_SYMBOL = "PAY";
  uint256 BASE_PAY_AMOUNT = 1e18; // Because our test token has 18 decimals

  event Bought(
    address indexed _payer,
    address indexed _receiver,
    uint256 indexed _tokenId,
    uint256 _paymentAmount,
    uint256 _creatorFee,
    uint256 _adminFee
  );
  event Sold(
    address indexed _seller,
    uint256 indexed _tokenId,
    uint256 _salePrice,
    uint256 _creatorFee,
    uint256 _adminFee
  );
  event ToggledPause(bool _oldPauseState, bool _newPauseState, address _caller);

  function setUp() public {
    payToken = new ERC20(PAY_TOKEN_NAME, PAY_TOKEN_SYMBOL);
    bondingCurve = new MockIncrementingBondingCurve(BASE_PAY_AMOUNT);
    creatorToken =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, creator, admin, payToken, bondingCurve);
  }

  function buyAToken(address _buyer) public {
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    uint256 _originalPayTokenBalanceOfBuyer = payToken.balanceOf(_buyer);
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_buyer), _originalBuyerBalanceOfCreatorTokens + 1);
    assertEq(creatorToken.ownerOf(creatorToken.lastId()), _buyer);
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract + _tokenPrice
    );
    assertEq(payToken.balanceOf(_buyer), _originalPayTokenBalanceOfBuyer);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply + 1);
  }

  function sellAToken(address _seller, uint256 _tokenId) public {
    require(
      creatorToken.ownerOf(_tokenId) == _seller,
      "Broken test invariant: seller does not own the token to sell."
    );
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;
    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(address(creatorToken));
    uint256 _originalPayTokenBalanceOfSeller = payToken.balanceOf(_seller);
    uint256 _originalSellerBalanceOfCreatorTokens = creatorToken.balanceOf(_seller);
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), _tokenId);
    creatorToken.sell(_tokenId, _netProceeds);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_seller), _originalSellerBalanceOfCreatorTokens - 1);
    assertEq(
      payToken.balanceOf(address(creatorToken)),
      _originalPayTokenBalanceOfCreatorTokenContract - _tokenPrice
    );
    assertEq(payToken.balanceOf(_seller), _originalPayTokenBalanceOfSeller + _netProceeds);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply - 1);
  }
}

contract Deployment is CreatorTokenTest {
  function test_TokenIsConfiguredAtDeployment() public {
    assertEq(creatorToken.name(), CREATOR_TOKEN_NAME);
    assertEq(creatorToken.symbol(), CREATOR_TOKEN_SYMBOL);
    assertEq(creatorToken.creator(), creator);
    assertEq(creatorToken.admin(), admin);
    assertEq(address(creatorToken.payToken()), address(payToken));
    assertEq(address(creatorToken.bondingCurve()), address(bondingCurve));
  }

  function test_RevertIf_TokenIsConfiguredWithZeroAddressAsCreator() public {
    CreatorToken _creatorTokenInstance;
    address _creatorZeroAddress = address(0);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    _creatorTokenInstance =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, _creatorZeroAddress, admin, payToken, bondingCurve);
  }

  function test_RevertIf_TokenIsConfiguredWithZeroAddressAsAdmin() public {
    CreatorToken _creatorTokenInstance;
    address _adminZeroAddress = address(0);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    _creatorTokenInstance =
    new CreatorToken(CREATOR_TOKEN_NAME, CREATOR_TOKEN_SYMBOL, creator, _adminZeroAddress, payToken, bondingCurve);
  }

  function test_FirstTokenIsMintedToCreator() public {
    assertEq(creatorToken.balanceOf(creator), 1);
    assertEq(creatorToken.ownerOf(1), creator);
  }
}

contract Buying is CreatorTokenTest {
  function test_SecondTokenIsBoughtForOnePaymentToken(address _buyer) public {
    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin
    );
    uint256 _originalBuyerBalanceOfCreatorTokens = creatorToken.balanceOf(_buyer);
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_buyer), _originalBuyerBalanceOfCreatorTokens + 1);
    assertEq(payToken.balanceOf(_buyer), 0);
    assertEq(payToken.balanceOf(address(creatorToken)), _tokenPrice);
    assertEq(payToken.balanceOf(creatorToken.creator()), _creatorFee);
    assertEq(payToken.balanceOf(creatorToken.admin()), _adminFee);
  }

  function test_BuyWithReceiverAddress(address _buyer, address _to) public {
    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin
    );
    vm.assume(_to != address(0) && _to != address(creatorToken));
    uint256 _originalReceiverBalanceOfCreatorTokens = creatorToken.balanceOf(_to);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_to, _totalPrice);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_to), _originalReceiverBalanceOfCreatorTokens + 1);
    assertEq(payToken.balanceOf(_buyer), 0);
    assertEq(payToken.balanceOf(address(creatorToken)), _tokenPrice);
    assertEq(payToken.balanceOf(creatorToken.creator()), _creatorFee);
    assertEq(payToken.balanceOf(creatorToken.admin()), _adminFee);
  }

  function test_EmitsBoughtEvent(address _buyer) public {
    vm.assume(_buyer != address(0) && _buyer != address(creatorToken));

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectEmit(true, true, true, true);
    emit Bought(_buyer, _buyer, creatorToken.lastId() + 1, _tokenPrice, _creatorFee, _adminFee);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();
  }

  function test_RevertIf_PriceExceedsMaxPayment(address _buyer, uint256 _maxPayment) public {
    vm.assume(_buyer != address(0) && _buyer != address(creatorToken));

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    _maxPayment = bound(_maxPayment, 0, _totalPrice - 1);
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MaxPaymentExceeded.selector, _totalPrice, _maxPayment
      )
    );
    creatorToken.buy(_maxPayment);
    vm.stopPrank();
  }
}

contract Selling is CreatorTokenTest {
  function test_SecondTokenIsSoldForOnePaymentToken(address _seller) public {
    vm.assume(
      _seller != address(0) && _seller != address(creatorToken) && _seller != creator
        && _seller != admin
    );
    buyAToken(_seller);

    uint256 _originalPayTokenBalanceOfCreatorTokenContract =
      payToken.balanceOf(creatorToken.creator());
    uint256 _originalPayTokenBalanceOfAdmin = payToken.balanceOf(creatorToken.admin());
    uint256 _originalCreatorTokenSupply = creatorToken.totalSupply();
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    vm.expectEmit(true, true, true, true);
    emit Sold(_seller, creatorToken.lastId(), _tokenPrice, _creatorFee, _adminFee);
    creatorToken.sell(creatorToken.lastId(), _netProceeds);
    vm.stopPrank();

    assertEq(creatorToken.balanceOf(_seller), 0);
    assertEq(creatorToken.totalSupply(), _originalCreatorTokenSupply - 1);
    assertEq(payToken.balanceOf(_seller), _netProceeds);
    assertEq(
      payToken.balanceOf(creatorToken.creator()),
      _originalPayTokenBalanceOfCreatorTokenContract + _creatorFee
    );
    assertEq(payToken.balanceOf(creatorToken.admin()), _originalPayTokenBalanceOfAdmin + _adminFee);
  }

  function test_RevertIf_MinAcceptedPriceIsHigherThanNetProceeds(
    address _seller,
    uint256 _minAcceptedPrice
  ) public {
    vm.assume(
      _seller != address(0) && _seller != address(creatorToken) && _seller != creator
        && _seller != admin
    );
    buyAToken(_seller);
    assertEq(creatorToken.ownerOf(creatorToken.lastId()), _seller);
    assertEq(payToken.balanceOf(_seller), 0);

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
    uint256 _netProceeds = _tokenPrice - _creatorFee - _adminFee;
    _minAcceptedPrice = bound(_minAcceptedPrice, _netProceeds + 1, type(uint256).max);
    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__MinAcceptedPriceExceeded.selector,
        _netProceeds,
        _minAcceptedPrice
      )
    );
    creatorToken.sell(_tokenId, _minAcceptedPrice);
    vm.stopPrank();
  }

  function test_RevertIf_SellerIsNotTokenOwner(address _owner, address _seller) public {
    vm.assume(
      _owner != address(0) && _owner != address(creatorToken) && _owner != creator
        && _owner != admin && _owner != _seller
    );
    vm.assume(
      _seller != address(0) && _seller != address(creatorToken) && _seller != creator
        && _seller != admin
    );
    buyAToken(_owner);

    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(_seller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__CallerIsNotOwner.selector, creatorToken.lastId(), _owner, _seller
      )
    );
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }

  function test_RevertIf_LastTokenIsBeingSold() public {
    require(
      creatorToken.ownerOf(creatorToken.lastId()) == creator,
      "Test invariant violated: creator should be owner of the last token"
    );
    uint256 _tokenId = creatorToken.lastId();

    vm.startPrank(creator);
    creatorToken.approve(address(creatorToken), _tokenId);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__LastTokenCannotBeSold.selector, creatorToken.totalSupply()
      )
    );
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }
}

contract UpdatingCreatorAndAdminAddresses is CreatorTokenTest {
  function test_UpdateCreatorAddress(address _newCreator, address _secondNewCreator) public {
    vm.assume(_newCreator != address(0) && _newCreator != creator);
    vm.assume(_secondNewCreator != address(0) && _secondNewCreator != _newCreator);

    vm.prank(creator);
    creatorToken.updateCreator(_newCreator);
    assertEq(creatorToken.creator(), _newCreator);

    vm.prank(_newCreator);
    creatorToken.updateCreator(_secondNewCreator);
    assertEq(creatorToken.creator(), _secondNewCreator);
  }

  function test_RevertIf_NewCreatorAddressIsZero() public {
    address _newCreator = address(0);

    vm.prank(creator);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    creatorToken.updateCreator(_newCreator);
  }

  function test_RevertIf_CallerIsNotCreator(address _caller, address _newCreator) public {
    vm.assume(_caller != address(0) && _caller != creator);
    vm.assume(_newCreator != address(0));

    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not creator"), _caller
      )
    );
    creatorToken.updateCreator(_newCreator);
  }

  function test_UpdateAdminAddress(address _newAdmin, address _secondNewAdmin) public {
    vm.assume(_newAdmin != address(0) && _newAdmin != admin);
    vm.assume(_secondNewAdmin != address(0) && _secondNewAdmin != _newAdmin);

    vm.prank(admin);
    creatorToken.updateAdmin(_newAdmin);
    assertEq(creatorToken.admin(), _newAdmin);

    vm.prank(_newAdmin);
    creatorToken.updateAdmin(_secondNewAdmin);
    assertEq(creatorToken.admin(), _secondNewAdmin);
  }

  function test_RevertIf_NewAdminAddressIsZero() public {
    address _newAdmin = address(0);

    vm.prank(admin);
    vm.expectRevert(CreatorToken.CreatorToken__AddressZeroNotAllowed.selector);
    creatorToken.updateAdmin(_newAdmin);
  }

  function test_RevertIf_CallerIsNotAdmin(address _caller, address _newAdmin) public {
    vm.assume(_caller != address(0) && _caller != admin);
    vm.assume(_newAdmin != address(0));

    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not admin"), _caller
      )
    );
    creatorToken.updateAdmin(_newAdmin);
  }
}

contract Pausing is CreatorTokenTest {
  function test_PauseContractCreator() public {
    vm.startPrank(creator);

    // Pause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(false, true, creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    // Unpause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(true, false, creator);
    creatorToken.pause(false);
    assertEq(creatorToken.isPaused(), false);

    vm.stopPrank();
  }

  function test_PauseContractAdmin() public {
    vm.startPrank(admin);

    // Pause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(false, true, admin);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    // Unpause
    vm.expectEmit(true, true, true, true);
    emit ToggledPause(true, false, admin);
    creatorToken.pause(false);
    assertEq(creatorToken.isPaused(), false);

    vm.stopPrank();
  }

  function test_RevertIf_CallerIsNotCreatorOrAdmin(address _caller, bool _pauseState) public {
    vm.assume(_caller != address(0) && _caller != creator && _caller != admin);

    vm.expectRevert(
      abi.encodeWithSelector(
        CreatorToken.CreatorToken__Unauthorized.selector, bytes32("not creator or admin"), _caller
      )
    );
    vm.prank(_caller);
    creatorToken.pause(_pauseState);
  }

  function test_RevertIf_PausedAndBuyIsCalled(address _buyer) public {
    vm.prank(creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin
    );

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.buy(_totalPrice);
    vm.stopPrank();
  }

  function test_RevertIf_PausedAndBuyIsCalled(address _buyer, address _receiver) public {
    vm.prank(creator);
    creatorToken.pause(true);
    assertEq(creatorToken.isPaused(), true);

    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin
    );

    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _buyer, _totalPrice);

    vm.startPrank(_buyer);
    payToken.approve(address(creatorToken), type(uint256).max);
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.buy(_receiver, _totalPrice);
    vm.stopPrank();
  }

  function test_RevertIf_PausedAndSellIsCalled(address _seller) public {
    vm.assume(
      _seller != address(0) && _seller != address(creatorToken) && _seller != creator
        && _seller != admin
    );

    // Buy a token
    (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
    uint256 _totalPrice = _tokenPrice + _creatorFee + _adminFee;
    deal(address(payToken), _seller, _totalPrice);

    vm.startPrank(_seller);
    payToken.approve(address(creatorToken), type(uint256).max);
    creatorToken.buy(_totalPrice);
    assertEq(creatorToken.balanceOf(_seller), 1);
    assertEq(creatorToken.ownerOf(creatorToken.lastId()), _seller);
    assertEq(payToken.balanceOf(address(creatorToken)), _tokenPrice);
    vm.stopPrank();

    // Pause
    vm.prank(creator);
    creatorToken.pause(true);

    // Try to sell the token
    vm.startPrank(_seller);
    creatorToken.approve(address(creatorToken), creatorToken.lastId());
    uint256 _tokenId = creatorToken.lastId();
    vm.expectRevert(CreatorToken.CreatorToken__ContractIsPaused.selector);
    creatorToken.sell(_tokenId);
    vm.stopPrank();
  }
}

contract CreatorTokenFollowsBondingCurveContract is CreatorTokenTest {
  function test_BuyPriceIsCorrect(address _buyer, uint256 _numTokensToBuy) public {
    vm.assume(
      _buyer != address(0) && _buyer != address(creatorToken) && _buyer != creator
        && _buyer != admin
    );
    _numTokensToBuy = bound(_numTokensToBuy, 1, 100);

    for (uint256 _i = 0; _i < _numTokensToBuy; _i++) {
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextBuyPrice();
      uint256 _bondingCurveTokenPrice =
        bondingCurve.priceForTokenNumber(creatorToken.totalSupply() + 1);
      (
        uint256 _creatorFeeCalculatedWithBondingCurveTokenPrice,
        uint256 _adminFeeCalculatedWithBondingCurveTokenPrice
      ) = creatorToken.calculateFees(_bondingCurveTokenPrice);

      assertEq(_tokenPrice, _bondingCurveTokenPrice);
      assertEq(_creatorFee, _creatorFeeCalculatedWithBondingCurveTokenPrice);
      assertEq(_adminFee, _adminFeeCalculatedWithBondingCurveTokenPrice);
      buyAToken(_buyer);
    }
  }

  function test_SellPriceIsCorrect(address _seller, uint256 _numTokensToBuyAndSell) public {
    vm.assume(
      _seller != address(0) && _seller != address(creatorToken) && _seller != creator
        && _seller != admin
    );
    _numTokensToBuyAndSell = bound(_numTokensToBuyAndSell, 1, 100);
    uint256[] memory _tokenIds = new uint256[](_numTokensToBuyAndSell);
    // buy n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      buyAToken(_seller);
      _tokenIds[_i] = (creatorToken.lastId());
    }
    require(creatorToken.balanceOf(_seller) == _numTokensToBuyAndSell);

    // sell n tokens
    for (uint256 _i = 0; _i < _numTokensToBuyAndSell; _i++) {
      (uint256 _tokenPrice, uint256 _creatorFee, uint256 _adminFee) = creatorToken.nextSellPrice();
      uint256 _bondingCurveTokenPrice = bondingCurve.priceForTokenNumber(creatorToken.totalSupply());
      (
        uint256 _creatorFeeCalculatedWithBondingCurveTokenPrice,
        uint256 _adminFeeCalculatedWithBondingCurveTokenPrice
      ) = creatorToken.calculateFees(_bondingCurveTokenPrice);

      assertEq(_tokenPrice, _bondingCurveTokenPrice);
      assertEq(_creatorFee, _creatorFeeCalculatedWithBondingCurveTokenPrice);
      assertEq(_adminFee, _adminFeeCalculatedWithBondingCurveTokenPrice);
      sellAToken(_seller, _tokenIds[_i]);
    }
  }
}
