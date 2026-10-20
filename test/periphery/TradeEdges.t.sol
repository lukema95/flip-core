// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../../src/Factory.sol";
import {Flip} from "../../src/Flip.sol";
import {Trade} from "../../src/periphery/Trade.sol";
import {Registry} from "../../src/Registry.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {IPrice} from "../../src/interfaces/core/IPrice.sol";
import {ITrade} from "../../src/interfaces/periphery/ITrade.sol";

/// @dev Buyer contract that cannot receive ETH refunds.
contract RejectingBuyer {
    Trade public immutable trade;

    constructor(Trade _trade) {
        trade = _trade;
    }

    function bulkMintFor(address flip, uint256 quantity) external payable {
        trade.bulkMint{value: msg.value}(flip, quantity);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        revert("no ETH");
    }
}

/// @dev Seller contract that cannot receive ETH payouts.
contract RejectingSeller {
    Trade public immutable trade;

    constructor(Trade _trade) {
        trade = _trade;
    }

    function approveAll(Flip flip) external {
        flip.setApprovalForAll(address(trade), true);
    }

    function sellAll(address flip, uint256[] calldata tokenIds) external {
        trade.bulkSell(flip, tokenIds);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        revert("no ETH");
    }
}

contract TradeEdgesTest is Test {
    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public price;
    Flip public implementation;
    Flip public flip;
    Trade public trade;

    address public alice = address(0xA11CE);

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        price = new Price();
        implementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(price), address(implementation));
        flip = Flip(factory.createFlip("Flip", "FLIP", 0.001 ether, 1000, 0, 0.05 ether, "https://example.com/m"));
        trade = new Trade();
    }

    function _mint(address to) internal returns (uint256 tokenId) {
        uint256 cost = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.deal(to, cost);
        vm.prank(to);
        tokenId = flip.mint{value: cost}();
    }

    function test_quickBuyRevertsWhenPoolIsEmpty() public {
        vm.expectRevert(ITrade.NoTokensAvailable.selector);
        trade.quickBuy(address(flip));
    }

    function test_bulkQuickBuyRevertsWhenPoolIsEmpty() public {
        vm.expectRevert(ITrade.NoTokensAvailable.selector);
        trade.bulkQuickBuy(address(flip), 1);
    }

    function test_bulkMintRevertsOnInsufficientPayment() public {
        vm.expectRevert(ITrade.InsufficientPayment.selector);
        trade.bulkMint{value: 1}(address(flip), 2);
    }

    function test_bulkQuickBuyRevertsOnInsufficientPayment() public {
        uint256 tokenId = _mint(address(this));
        flip.sell(tokenId);

        uint256 required = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.deal(address(this), required);
        vm.expectRevert(ITrade.InsufficientPayment.selector);
        trade.bulkQuickBuy{value: required - 1}(address(flip), 1);
    }

    function test_bulkBuyRevertsOnInsufficientPayment() public {
        uint256 tokenId = _mint(address(this));
        flip.sell(tokenId);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.expectRevert(ITrade.InsufficientPayment.selector);
        trade.bulkBuy{value: 1}(address(flip), tokenIds);
    }

    function test_bulkSellRevertsWhenCallerIsNotOwner() public {
        uint256 tokenId = _mint(address(this));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.prank(alice);
        vm.expectRevert(ITrade.NotTokenOwner.selector);
        trade.bulkSell(address(flip), tokenIds);
    }

    function test_bulkMintRevertsWhenRefundFails() public {
        RejectingBuyer buyer = new RejectingBuyer(trade);
        uint256 required = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        uint256 value = required + 1 ether;
        vm.deal(address(buyer), value);

        vm.expectRevert(ITrade.RefundFailed.selector);
        buyer.bulkMintFor{value: value}(address(flip), 1);
    }

    function test_bulkSellRevertsWhenPayoutFails() public {
        RejectingSeller seller = new RejectingSeller(trade);
        uint256 tokenId = _mint(address(this));
        flip.safeTransferFrom(address(this), address(seller), tokenId);
        seller.approveAll(flip);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.expectRevert(ITrade.TransferFailed.selector);
        seller.sellAll(address(flip), tokenIds);
    }
}
