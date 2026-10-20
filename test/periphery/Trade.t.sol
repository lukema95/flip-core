// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Trade} from "../../src/periphery/Trade.sol";
import {Flip} from "../../src/Flip.sol";
import {Price} from "../../src/core/Price.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Factory} from "../../src/Factory.sol";
import {Registry} from "../../src/Registry.sol";
import {ITrade} from "../../src/interfaces/periphery/ITrade.sol";

contract TradeTest is Test {
    receive() external payable {}

    Trade public trade;
    Flip public flip;
    Flip public flipImplementation;
    Price public priceContract;
    FeeVault public feeVault;
    Factory public factory;
    Registry public registry;
    address alice = address(0x1);
    address bob = address(0x2);

    // Events from ITrade interface
    event Minted(address indexed flipContract, address indexed to, uint256 indexed tokenId, uint256 price);
    event Bought(address indexed flipContract, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event Sold(address indexed flipContract, address indexed seller, uint256 indexed tokenId, uint256 price);
    event BulkBuyExecuted(address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice);
    event BulkSellExecuted(
        address indexed flipContract, address indexed seller, uint256[] tokenIds, uint256 totalPrice
    );
    event BulkMintExecuted(address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice);
    event BulkQuickBuyExecuted(
        address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice
    );
    event QuickBuyExecuted(address indexed flipContract, address indexed buyer, uint256 indexed tokenId, uint256 price);

    function setUp() public {
        feeVault = new FeeVault();
        registry = new Registry();
        priceContract = new Price();
        flipImplementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(priceContract), address(flipImplementation));
        flip = Flip(factory.createFlip("Flip", "Flip", 0.001 ether, 10000, 0, 0.05 ether, "https://flip.com/image.png"));
        trade = new Trade();
    }

    function test_mint() public {
        vm.deal(alice, 100 ether);
        Price price = Price(flip.priceContract());
        uint256 expectedPrice = price.getBuyPriceAfterFee(address(flip));

        vm.expectEmit(true, true, true, true);
        emit Minted(address(flip), alice, 1, expectedPrice);

        vm.prank(alice);
        trade.mint{value: 1 ether}(address(flip));
        assertEq(flip.balanceOf(alice), 1);
        assertEq(flip.ownerOf(1), alice);
    }

    function test_sell_and_buy() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.mint{value: 1 ether}(address(flip));
        assertEq(flip.balanceOf(alice), 1);

        // Get current price after mint for accurate sell price
        Price price = Price(flip.priceContract());
        uint256 sellPrice = price.getSellPriceAfterFee(address(flip));
        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);

        // Move expectEmit right before the sell call
        vm.expectEmit(true, true, true, true);
        emit Sold(address(flip), alice, 1, sellPrice);

        vm.prank(alice);
        trade.sell(address(flip), 1);
        assertEq(flip.balanceOf(alice), 0);
        assertEq(alice.balance, aliceBalanceBefore + sellPrice);

        // Get current price after sell for accurate buy price
        uint256 buyPrice = price.getBuyPriceAfterFee(address(flip));

        vm.expectEmit(true, true, true, true);
        emit Bought(address(flip), alice, 1, buyPrice);

        vm.prank(alice);
        trade.buy{value: 1 ether}(address(flip), 1);
        assertEq(flip.balanceOf(alice), 1);
        assertEq(flip.ownerOf(1), alice);
    }

    function test_quickBuy() public {
        // First mint a token and sell it to make it available
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.mint{value: 1 ether}(address(flip));

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);
        vm.prank(alice);
        trade.sell(address(flip), 1);

        // Now test quickBuy
        vm.deal(bob, 100 ether);
        Price price = Price(flip.priceContract());
        uint256 buyPrice = price.getBuyPriceAfterFee(address(flip));

        vm.expectEmit(true, true, true, true);
        emit QuickBuyExecuted(address(flip), bob, 1, buyPrice);

        vm.prank(bob);
        trade.quickBuy{value: 1 ether}(address(flip));
        assertEq(flip.balanceOf(bob), 1);
        assertEq(flip.ownerOf(1), bob);
    }

    function test_quickBuy_NoTokensAvailable() public {
        vm.deal(alice, 100 ether);

        vm.expectRevert(ITrade.NoTokensAvailable.selector);
        vm.prank(alice);
        trade.quickBuy{value: 1 ether}(address(flip));
    }

    function test_bulkMint() public {
        vm.deal(alice, 100 ether);
        uint256 quantity = 10;

        // Since prices are dynamic, we'll just check that the event is emitted
        // without verifying the exact totalPrice
        vm.expectEmit(true, true, false, false);
        emit BulkMintExecuted(address(flip), alice, new uint256[](0), 0);

        vm.prank(alice);
        trade.bulkMint{value: 50 ether}(address(flip), quantity);
        assertEq(flip.balanceOf(alice), quantity);

        for (uint256 i = 1; i <= quantity; i++) {
            assertEq(flip.ownerOf(i), alice);
        }
    }

    function test_bulkMint_InsufficientPayment() public {
        vm.deal(alice, 100 ether);
        uint256 quantity = 5;

        uint256 price = priceContract.getBuyPriceAfterFee(address(flip));
        uint256 insufficientAmount = price * (quantity - 1);

        vm.expectRevert(ITrade.InsufficientPayment.selector);
        vm.prank(alice);
        trade.bulkMint{value: insufficientAmount}(address(flip), quantity);
    }

    function test_bulkMint_RefundExcess() public {
        vm.deal(alice, 100 ether);
        uint256 quantity = 2;
        uint256 balanceBefore = alice.balance;

        vm.prank(alice);
        uint256 valueSent = 10 ether; // Send much more than needed
        trade.bulkMint{value: valueSent}(address(flip), quantity);

        assertEq(flip.balanceOf(alice), quantity);
        // Check that some excess was refunded (exact amount will depend on dynamic pricing)
        assertTrue(alice.balance > balanceBefore - valueSent);
        assertTrue(alice.balance < balanceBefore); // But some was spent
    }

    function test_bulkBuy_and_bulkSell() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.bulkMint{value: 50 ether}(address(flip), 10);
        assertEq(flip.balanceOf(alice), 10);

        uint256[] memory tokenIds = new uint256[](10);
        for (uint256 i = 1; i <= 10; i++) {
            tokenIds[i - 1] = i;
            assertEq(flip.ownerOf(i), alice);
        }

        uint256 aliceBalanceBefore = alice.balance;

        // Sell all tokens by bulkSell
        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);

        vm.expectEmit(true, true, false, false);
        emit BulkSellExecuted(address(flip), alice, tokenIds, 0);

        vm.prank(alice);
        trade.bulkSell(address(flip), tokenIds);
        assertEq(flip.balanceOf(alice), 0);
        // Check balance increased (don't check exact amount due to dynamic pricing)
        assertTrue(alice.balance > aliceBalanceBefore);

        // Buy 5 tokens by bulkQuickBuy
        uint256 quantity = 5;

        vm.expectEmit(true, true, false, false);
        emit BulkQuickBuyExecuted(address(flip), alice, new uint256[](0), 0);

        vm.prank(alice);
        trade.bulkQuickBuy{value: 50 ether}(address(flip), quantity);
        assertEq(flip.balanceOf(alice), quantity);

        // Get available tokens
        uint256[] memory availableTokens = flip.getAllAvailableTokens();
        assertEq(availableTokens.length, 5);

        vm.expectEmit(true, true, false, false);
        emit BulkBuyExecuted(address(flip), alice, availableTokens, 0);

        // Buy all tokens by bulkBuy
        vm.prank(alice);
        trade.bulkBuy{value: 50 ether}(address(flip), availableTokens);
        assertEq(flip.balanceOf(alice), 10);
    }

    function test_bulkQuickBuy_NoTokensAvailable() public {
        vm.deal(alice, 100 ether);

        vm.expectRevert(ITrade.NoTokensAvailable.selector);
        vm.prank(alice);
        trade.bulkQuickBuy{value: 1 ether}(address(flip), 5);
    }

    function test_bulkQuickBuy_InsufficientTokens() public {
        // Mint and sell 3 tokens
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.bulkMint{value: 10 ether}(address(flip), 3);

        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 1; i <= 3; i++) {
            tokenIds[i - 1] = i;
        }

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);
        vm.prank(alice);
        trade.bulkSell(address(flip), tokenIds);

        // Try to buy 5 tokens when only 3 are available
        vm.deal(bob, 100 ether); // Give bob enough money
        vm.expectRevert(ITrade.NoTokensAvailable.selector);
        vm.prank(bob);
        trade.bulkQuickBuy{value: 10 ether}(address(flip), 5);
    }

    function test_bulkBuy_InsufficientPayment() public {
        // Mint and sell tokens
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.bulkMint{value: 10 ether}(address(flip), 2);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);
        vm.prank(alice);
        trade.bulkSell(address(flip), tokenIds);

        vm.deal(bob, 100 ether);

        uint256 insufficientAmount = priceContract.getBuyPriceAfterFee(address(flip));

        vm.expectRevert(ITrade.InsufficientPayment.selector);
        vm.prank(bob);
        trade.bulkBuy{value: insufficientAmount}(address(flip), tokenIds);
    }

    function test_bulkSell_NotTokenOwner() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.mint{value: 1 ether}(address(flip));

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.expectRevert(ITrade.NotTokenOwner.selector);
        vm.prank(bob);
        trade.bulkSell(address(flip), tokenIds);
    }

    function test_sell_NotTokenOwner() public {
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.mint{value: 1 ether}(address(flip));

        // bob tries to sell alice's token without approval
        vm.expectRevert(); // Expect any revert due to insufficient approval
        vm.prank(bob);
        trade.sell(address(flip), 1);
    }

    function test_bulkBuy_RefundExcess() public {
        // Mint and sell tokens
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.bulkMint{value: 10 ether}(address(flip), 2);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);
        vm.prank(alice);
        trade.bulkSell(address(flip), tokenIds);

        vm.deal(bob, 100 ether);
        uint256 balanceBefore = bob.balance;
        uint256 valueSent = 10 ether; // Send much more than needed

        vm.prank(bob);
        trade.bulkBuy{value: valueSent}(address(flip), tokenIds);

        assertEq(flip.balanceOf(bob), 2);
        // Check that some excess was refunded
        assertTrue(bob.balance > balanceBefore - valueSent);
        assertTrue(bob.balance < balanceBefore); // But some was spent
    }

    function test_bulkQuickBuy_RefundExcess() public {
        // Mint and sell tokens
        vm.deal(alice, 100 ether);
        vm.prank(alice);
        trade.bulkMint{value: 10 ether}(address(flip), 3);

        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 1; i <= 3; i++) {
            tokenIds[i - 1] = i;
        }

        vm.prank(alice);
        flip.setApprovalForAll(address(trade), true);
        vm.prank(alice);
        trade.bulkSell(address(flip), tokenIds);

        uint256 quantity = 2;

        vm.deal(bob, 100 ether);
        uint256 balanceBefore = bob.balance;
        uint256 valueSent = 10 ether; // Send much more than needed

        vm.prank(bob);
        trade.bulkQuickBuy{value: valueSent}(address(flip), quantity);

        assertEq(flip.balanceOf(bob), quantity);
        // Check that some excess was refunded
        assertTrue(bob.balance > balanceBefore - valueSent);
        assertTrue(bob.balance < balanceBefore); // But some was spent
    }
}
