// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {LinearPrice} from "../../src/extensions/bodingcurve/LinearPrice.sol";
import {FixedIncrementPrice} from "../../src/extensions/bodingcurve/FixedIncrementPrice.sol";
import {Storage} from "../../src/core/Storage.sol";
import {Price} from "../../src/core/Price.sol";

// Concrete Storage implementation for testing
contract TestStorage is Storage {
    function initialize(
        uint256 _initialPrice,
        uint256 _maxSupply,
        uint256 _maxPrice,
        uint256 _creatorFeePercent,
        address _feeVault,
        address _priceContract,
        address _creator,
        string memory _uri
    ) external initializer {
        __Storage_init(
            _initialPrice, _maxSupply, _maxPrice, _creatorFeePercent, _feeVault, _priceContract, _creator, _uri
        );
    }

    // Make internal functions public for testing
    function incrementCurrentSupply() external {
        _incrementCurrentSupply();
    }

    function decrementCurrentSupply() external {
        _decrementCurrentSupply();
    }
}

contract BondingCurveTest is Test {
    LinearPrice public linearPrice;
    FixedIncrementPrice public fixedIncrementPrice;
    Price public basePrice;
    TestStorage public storageContract;

    uint256 public constant INITIAL_PRICE = 1 ether;
    uint256 public constant MAX_PRICE = 10 ether;
    uint256 public constant CREATOR_FEE_PERCENT = 500; // 5%
    uint256 public constant PRICE_MULTIPLIER = 1100; // 1.1x
    uint256 public constant PRICE_INCREMENT = 0.1 ether;

    function setUp() public {
        // Deploy price contracts
        linearPrice = new LinearPrice(PRICE_MULTIPLIER);
        fixedIncrementPrice = new FixedIncrementPrice(PRICE_INCREMENT);
        basePrice = new Price();

        // Deploy storage contract
        storageContract = new TestStorage();

        // Initialize storage with maxPrice
        storageContract.initialize(
            INITIAL_PRICE,
            1000, // maxSupply
            MAX_PRICE, // maxPrice
            CREATOR_FEE_PERCENT,
            address(0), // feeVault
            address(basePrice), // priceContract
            address(this), // creator
            "" // baseURI
        );
    }

    // ============ LinearPrice Tests ============

    function testLinearPriceConstructor() public {
        // Test valid multiplier
        LinearPrice validPrice = new LinearPrice(1100);
        assertEq(validPrice.PRICE_MULTIPLIER(), 1100);

        // Test invalid multiplier (too low)
        vm.expectRevert(LinearPrice.InvalidMultiplier.selector);
        new LinearPrice(999);

        // Test invalid multiplier (too high)
        vm.expectRevert(LinearPrice.InvalidMultiplier.selector);
        new LinearPrice(2001);
    }

    function testLinearPriceBasicCalculation() public {
        // Test supply = 0
        uint256 price0 = linearPrice.calculatePrice(address(storageContract), 0);
        assertEq(price0, INITIAL_PRICE, "Price for supply 0 should be initial price");

        // Test supply = 1
        uint256 price1 = linearPrice.calculatePrice(address(storageContract), 1);
        uint256 expectedPrice1 = INITIAL_PRICE + (INITIAL_PRICE * PRICE_MULTIPLIER) / 1000;
        assertEq(price1, expectedPrice1, "Price calculation incorrect for supply 1");

        // Test supply = 2
        uint256 price2 = linearPrice.calculatePrice(address(storageContract), 2);
        assertGt(price2, price1, "Price should increase with supply");
    }

    function testLinearPriceWithMaxPrice() public {
        // Test that prices are capped at maxPrice
        uint256 price10 = linearPrice.calculatePrice(address(storageContract), 10);
        uint256 price20 = linearPrice.calculatePrice(address(storageContract), 20);
        uint256 price50 = linearPrice.calculatePrice(address(storageContract), 50);

        console.log("Linear Price - Supply 10:", price10 / 1e18, "ETH");
        console.log("Linear Price - Supply 20:", price20 / 1e18, "ETH");
        console.log("Linear Price - Supply 50:", price50 / 1e18, "ETH");

        assertLe(price10, MAX_PRICE, "Price should not exceed maxPrice");
        assertLe(price20, MAX_PRICE, "Price should not exceed maxPrice");
        assertLe(price50, MAX_PRICE, "Price should not exceed maxPrice");
    }

    function testLinearPriceNoMaxPrice() public {
        // Create storage without maxPrice (0 = no limit)
        TestStorage storageNoLimit = new TestStorage();
        storageNoLimit.initialize(
            INITIAL_PRICE,
            1000, // maxSupply
            0, // maxPrice = no limit
            CREATOR_FEE_PERCENT,
            address(0), // feeVault
            address(basePrice), // priceContract
            address(this), // creator
            "" // baseURI
        );

        // Test that prices can exceed the previous maxPrice
        uint256 price20 = linearPrice.calculatePrice(address(storageNoLimit), 20);
        uint256 price50 = linearPrice.calculatePrice(address(storageNoLimit), 50);

        console.log("Linear Price (No Limit) - Supply 20:", price20 / 1e18, "ETH");
        console.log("Linear Price (No Limit) - Supply 50:", price50 / 1e18, "ETH");

        assertGt(price20, MAX_PRICE, "Price should be able to exceed previous maxPrice");
        assertGt(price50, MAX_PRICE, "Price should be able to exceed previous maxPrice");
    }

    function testLinearPriceWithCustomMultiplier() public {
        uint256 customMultiplier = 1200; // 1.2x
        uint256 supply = 5;

        uint256 price = linearPrice.calculatePriceWithMultiplier(address(storageContract), supply, customMultiplier);

        console.log("Linear Price with custom multiplier 1.2x:", price / 1e18, "ETH");

        // Verify price is reasonable
        assertGt(price, INITIAL_PRICE, "Price should be greater than initial price");
        assertLe(price, MAX_PRICE, "Price should not exceed maxPrice");
    }

    function testLinearPriceBuySellPrices() public {
        // Set current supply to 5
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();

        assertEq(storageContract.currentSupply(), 5, "Current supply should be 5");

        // Test buy price (should be price for supply 5)
        uint256 buyPrice = linearPrice.getBuyPrice(address(storageContract));
        uint256 expectedBuyPrice = linearPrice.calculatePrice(address(storageContract), 5);
        assertEq(buyPrice, expectedBuyPrice, "Buy price should match calculated price for current supply");

        // Test sell price (should be price for supply 4)
        uint256 sellPrice = linearPrice.getSellPrice(address(storageContract));
        uint256 expectedSellPrice = linearPrice.calculatePrice(address(storageContract), 4);
        assertEq(sellPrice, expectedSellPrice, "Sell price should match calculated price for current supply - 1");

        // Verify sell price is less than buy price
        assertLt(sellPrice, buyPrice, "Sell price should be less than buy price");
    }

    function testLinearPriceWithFees() public {
        uint256 buyPrice = linearPrice.getBuyPrice(address(storageContract));
        uint256 buyPriceWithFee = linearPrice.getBuyPriceAfterFee(address(storageContract));
        uint256 sellPrice = linearPrice.getSellPrice(address(storageContract));
        uint256 sellPriceWithFee = linearPrice.getSellPriceAfterFee(address(storageContract));

        // Calculate expected fees
        uint256 expectedBuyFee = buyPrice * CREATOR_FEE_PERCENT / 1 ether;
        uint256 expectedSellFee = sellPrice * CREATOR_FEE_PERCENT / 1 ether;

        // Verify buy price with fee
        assertEq(buyPriceWithFee, buyPrice + expectedBuyFee, "Buy price with fee calculation incorrect");

        // Verify sell price with fee
        assertEq(sellPriceWithFee, sellPrice - expectedSellFee, "Sell price with fee calculation incorrect");
    }

    function testLinearPriceGetBuyPriceAndFee() public {
        (uint256 price, uint256 fee) = linearPrice.getBuyPriceAndFee(address(storageContract));

        uint256 expectedPrice = linearPrice.getBuyPrice(address(storageContract));
        uint256 expectedFee = expectedPrice * CREATOR_FEE_PERCENT / 1 ether;

        assertEq(price, expectedPrice, "Price should match buy price");
        assertEq(fee, expectedFee, "Fee calculation incorrect");
    }

    function testLinearPriceGetSellPriceAndFee() public {
        (uint256 price, uint256 fee) = linearPrice.getSellPriceAndFee(address(storageContract));

        uint256 expectedPrice = linearPrice.getSellPrice(address(storageContract));
        uint256 expectedFee = expectedPrice * CREATOR_FEE_PERCENT / 1 ether;

        assertEq(price, expectedPrice, "Price should match sell price");
        assertEq(fee, expectedFee, "Fee calculation incorrect");
    }

    // ============ FixedIncrementPrice Tests ============

    function testFixedIncrementPriceConstructor() public {
        // Test valid increment
        FixedIncrementPrice validPrice = new FixedIncrementPrice(0.1 ether);
        assertEq(validPrice.PRICE_INCREMENT(), 0.1 ether);

        // Test invalid increment (zero)
        vm.expectRevert(FixedIncrementPrice.InvalidIncrement.selector);
        new FixedIncrementPrice(0);
    }

    function testFixedIncrementPriceBasicCalculation() public {
        // Test supply = 0
        uint256 price0 = fixedIncrementPrice.calculatePrice(address(storageContract), 0);
        assertEq(price0, INITIAL_PRICE, "Price for supply 0 should be initial price");

        // Test supply = 1
        uint256 price1 = fixedIncrementPrice.calculatePrice(address(storageContract), 1);
        uint256 expectedPrice1 = INITIAL_PRICE + PRICE_INCREMENT;
        assertEq(price1, expectedPrice1, "Price calculation incorrect for supply 1");

        // Test supply = 5
        uint256 price5 = fixedIncrementPrice.calculatePrice(address(storageContract), 5);
        uint256 expectedPrice5 = INITIAL_PRICE + 5 * PRICE_INCREMENT;
        assertEq(price5, expectedPrice5, "Price calculation incorrect for supply 5");

        // Verify linear growth
        assertEq(price5 - price1, 4 * PRICE_INCREMENT, "Price should grow linearly");
    }

    function testFixedIncrementPriceWithMaxPrice() public {
        // Test that prices are capped at maxPrice
        uint256 price10 = fixedIncrementPrice.calculatePrice(address(storageContract), 10);
        uint256 price20 = fixedIncrementPrice.calculatePrice(address(storageContract), 20);
        uint256 price50 = fixedIncrementPrice.calculatePrice(address(storageContract), 50);

        console.log("Fixed Increment Price - Supply 10:", price10 / 1e18, "ETH");
        console.log("Fixed Increment Price - Supply 20:", price20 / 1e18, "ETH");
        console.log("Fixed Increment Price - Supply 50:", price50 / 1e18, "ETH");

        assertLe(price10, MAX_PRICE, "Price should not exceed maxPrice");
        assertLe(price20, MAX_PRICE, "Price should not exceed maxPrice");
        assertLe(price50, MAX_PRICE, "Price should not exceed maxPrice");

        // Verify that prices are capped at maxPrice
        uint256 expectedPrice20 = INITIAL_PRICE + 20 * PRICE_INCREMENT;
        if (expectedPrice20 > MAX_PRICE) {
            assertEq(price20, MAX_PRICE, "Price should be capped at maxPrice");
        }
    }

    function testFixedIncrementPriceNoMaxPrice() public {
        // Create storage without maxPrice (0 = no limit)
        TestStorage storageNoLimit = new TestStorage();
        storageNoLimit.initialize(
            INITIAL_PRICE,
            1000, // maxSupply
            0, // maxPrice = no limit
            CREATOR_FEE_PERCENT,
            address(0), // feeVault
            address(basePrice), // priceContract
            address(this), // creator
            "" // baseURI
        );

        // Test that prices can exceed the previous maxPrice
        // Use larger supply to ensure price exceeds MAX_PRICE (10 ETH)
        uint256 supplyToExceedMaxPrice = (MAX_PRICE - INITIAL_PRICE) / PRICE_INCREMENT + 1;
        uint256 priceExceedsMax = fixedIncrementPrice.calculatePrice(address(storageNoLimit), supplyToExceedMaxPrice);
        uint256 price100 = fixedIncrementPrice.calculatePrice(address(storageNoLimit), 100);

        console.log("Fixed Increment Price (No Limit) - Supply 100:", price100 / 1e18, "ETH");
        console.log("Price exceeds max:", priceExceedsMax / 1e18, "ETH");

        assertGt(priceExceedsMax, MAX_PRICE, "Price should be able to exceed previous maxPrice");
        assertGt(price100, MAX_PRICE, "Price should be able to exceed previous maxPrice");
    }

    function testFixedIncrementPriceWithCustomIncrement() public {
        uint256 customIncrement = 0.2 ether;
        uint256 supply = 5;

        uint256 price =
            fixedIncrementPrice.calculatePriceWithIncrement(address(storageContract), supply, customIncrement);

        uint256 expectedPrice = INITIAL_PRICE + supply * customIncrement;
        assertEq(price, expectedPrice, "Price with custom increment calculation incorrect");

        console.log("Fixed Increment Price with custom increment 0.2 ETH:", price / 1e18, "ETH");
    }

    function testFixedIncrementPriceCalculateTotalCost() public {
        uint256 currentSupply = 0;
        uint256 tokensToMint = 3;

        uint256 totalCost =
            fixedIncrementPrice.calculateTotalCost(address(storageContract), currentSupply, tokensToMint);

        // Calculate expected total cost manually
        uint256 expectedTotalCost = 0;
        for (uint256 i = 0; i < tokensToMint; i++) {
            uint256 tokenPrice = INITIAL_PRICE + (currentSupply + i) * PRICE_INCREMENT;
            if (tokenPrice > MAX_PRICE) {
                tokenPrice = MAX_PRICE;
            }
            expectedTotalCost += tokenPrice;
        }

        assertEq(totalCost, expectedTotalCost, "Total cost calculation incorrect");
        console.log("Total cost for minting 3 tokens:", totalCost / 1e18, "ETH");
    }

    function testFixedIncrementPriceCalculateTotalCostWithCustomIncrement() public {
        uint256 currentSupply = 0;
        uint256 tokensToMint = 3;
        uint256 customIncrement = 0.2 ether;

        uint256 totalCost = fixedIncrementPrice.calculateTotalCostWithIncrement(
            address(storageContract), currentSupply, tokensToMint, customIncrement
        );

        // Calculate expected total cost manually
        uint256 expectedTotalCost = 0;
        for (uint256 i = 0; i < tokensToMint; i++) {
            uint256 tokenPrice = INITIAL_PRICE + (currentSupply + i) * customIncrement;
            if (tokenPrice > MAX_PRICE) {
                tokenPrice = MAX_PRICE;
            }
            expectedTotalCost += tokenPrice;
        }

        assertEq(totalCost, expectedTotalCost, "Total cost with custom increment calculation incorrect");
        console.log("Total cost for minting 3 tokens with 0.2 ETH increment:", totalCost / 1e18, "ETH");
    }

    function testFixedIncrementPriceBuySellPrices() public {
        // Set current supply to 5
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();
        storageContract.incrementCurrentSupply();

        assertEq(storageContract.currentSupply(), 5, "Current supply should be 5");

        // Test buy price (should be price for supply 5)
        uint256 buyPrice = fixedIncrementPrice.getBuyPrice(address(storageContract));
        uint256 expectedBuyPrice = fixedIncrementPrice.calculatePrice(address(storageContract), 5);
        assertEq(buyPrice, expectedBuyPrice, "Buy price should match calculated price for current supply");

        // Test sell price (should be price for supply 4)
        uint256 sellPrice = fixedIncrementPrice.getSellPrice(address(storageContract));
        uint256 expectedSellPrice = fixedIncrementPrice.calculatePrice(address(storageContract), 4);
        assertEq(sellPrice, expectedSellPrice, "Sell price should match calculated price for current supply - 1");

        // Verify sell price is less than buy price
        assertLt(sellPrice, buyPrice, "Sell price should be less than buy price");
    }

    function testFixedIncrementPriceWithFees() public {
        uint256 buyPrice = fixedIncrementPrice.getBuyPrice(address(storageContract));
        uint256 buyPriceWithFee = fixedIncrementPrice.getBuyPriceAfterFee(address(storageContract));
        uint256 sellPrice = fixedIncrementPrice.getSellPrice(address(storageContract));
        uint256 sellPriceWithFee = fixedIncrementPrice.getSellPriceAfterFee(address(storageContract));

        // Calculate expected fees
        uint256 expectedBuyFee = buyPrice * CREATOR_FEE_PERCENT / 1 ether;
        uint256 expectedSellFee = sellPrice * CREATOR_FEE_PERCENT / 1 ether;

        // Verify buy price with fee
        assertEq(buyPriceWithFee, buyPrice + expectedBuyFee, "Buy price with fee calculation incorrect");

        // Verify sell price with fee
        assertEq(sellPriceWithFee, sellPrice - expectedSellFee, "Sell price with fee calculation incorrect");
    }

    function testFixedIncrementPriceGetBuyPriceAndFee() public {
        (uint256 price, uint256 fee) = fixedIncrementPrice.getBuyPriceAndFee(address(storageContract));

        uint256 expectedPrice = fixedIncrementPrice.getBuyPrice(address(storageContract));
        uint256 expectedFee = expectedPrice * CREATOR_FEE_PERCENT / 1 ether;

        assertEq(price, expectedPrice, "Price should match buy price");
        assertEq(fee, expectedFee, "Fee calculation incorrect");
    }

    function testFixedIncrementPriceGetSellPriceAndFee() public {
        (uint256 price, uint256 fee) = fixedIncrementPrice.getSellPriceAndFee(address(storageContract));

        uint256 expectedPrice = fixedIncrementPrice.getSellPrice(address(storageContract));
        uint256 expectedFee = expectedPrice * CREATOR_FEE_PERCENT / 1 ether;

        assertEq(price, expectedPrice, "Price should match sell price");
        assertEq(fee, expectedFee, "Fee calculation incorrect");
    }

    // ============ Edge Cases and Error Tests ============

    function testLinearPriceEdgeCaseSupplyZero() public {
        uint256 price = linearPrice.calculatePrice(address(storageContract), 0);
        assertEq(price, INITIAL_PRICE, "Price for supply 0 should be initial price");
    }

    function testFixedIncrementPriceEdgeCaseSupplyZero() public {
        uint256 price = fixedIncrementPrice.calculatePrice(address(storageContract), 0);
        assertEq(price, INITIAL_PRICE, "Price for supply 0 should be initial price");
    }

    function testLinearPriceEdgeCaseLargeSupply() public {
        // Test with very large supply to ensure no overflow
        uint256 largeSupply = 1000;
        uint256 price = linearPrice.calculatePrice(address(storageContract), largeSupply);

        // Should not revert and should be capped at maxPrice
        assertLe(price, MAX_PRICE, "Price should be capped at maxPrice for large supply");
        assertGt(price, 0, "Price should be greater than 0");
    }

    function testFixedIncrementPriceEdgeCaseLargeSupply() public {
        // Test with very large supply to ensure no overflow
        uint256 largeSupply = 1000;
        uint256 price = fixedIncrementPrice.calculatePrice(address(storageContract), largeSupply);

        // Should not revert and should be capped at maxPrice
        assertLe(price, MAX_PRICE, "Price should be capped at maxPrice for large supply");
        assertGt(price, 0, "Price should be greater than 0");
    }

    function testLinearPriceGasOptimization() public {
        uint256 gasBefore = gasleft();
        linearPrice.calculatePrice(address(storageContract), 100);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("LinearPrice gas used for supply 100:", gasUsed);

        // Gas usage should be reasonable for O(1) calculation
        assertLt(gasUsed, 100000, "Gas usage too high for O(1) calculation");
    }

    function testFixedIncrementPriceGasOptimization() public {
        uint256 gasBefore = gasleft();
        fixedIncrementPrice.calculatePrice(address(storageContract), 100);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("FixedIncrementPrice gas used for supply 100:", gasUsed);

        // Gas usage should be reasonable for O(1) calculation
        assertLt(gasUsed, 50000, "Gas usage too high for O(1) calculation");
    }
}
