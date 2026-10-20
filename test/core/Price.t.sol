// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../../src/Factory.sol";
import {Flip} from "../../src/Flip.sol";
import {Registry} from "../../src/Registry.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {IPrice} from "../../src/interfaces/core/IPrice.sol";

contract PriceTest is Test {
    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public price;
    Flip public implementation;

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        price = new Price();
        implementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(price), address(implementation));
    }

    function _create(uint256 initialPrice, uint256 maxSupply, uint256 maxPrice) internal returns (Flip flip) {
        flip = Flip(
            factory.createFlip("Flip", "FLIP", initialPrice, maxSupply, maxPrice, 0.05 ether, "https://example.com/m")
        );
    }

    function test_sellPriceWhenNothingIsMinted() public {
        Flip flip = _create(0.001 ether, 1000, 0);

        // currentSupply == 0 exercises the `supply > 0 ? supply - 1 : 0` false branch
        assertEq(price.getSellPrice(address(flip)), 0.001 ether);
        assertEq(price.getSellPriceAfterFee(address(flip)), 0.001 ether - 0.00005 ether);
    }

    function test_buyPriceAtSupplyZero() public {
        Flip flip = _create(0.001 ether, 1000, 0);

        assertEq(price.getBuyPrice(address(flip)), 0.001 ether);
        assertEq(price.calculatePrice(address(flip), 0), 0.001 ether);
    }

    function test_priceIsCappedByMaxPrice() public {
        Flip flip = _create(0.001 ether, 100, 0.002 ether);

        // at supply 50 the curve is far above 0.002 ETH, so the cap applies
        assertEq(price.calculatePrice(address(flip), 50), 0.002 ether);
    }

    function test_priceBelowTheCapIsNotCapped() public {
        Flip flip = _create(0.001 ether, 10000, 10 ether);

        uint256 quoted = price.calculatePrice(address(flip), 1);
        assertGt(quoted, 0.001 ether);
        assertLt(quoted, 10 ether);
    }

    function test_buyAndSellPriceAndFee() public {
        Flip flip = _create(0.001 ether, 1000, 0);

        (uint256 buyPrice, uint256 buyFee) = price.getBuyPriceAndFee(address(flip));
        assertEq(price.getBuyPriceAfterFee(address(flip)), buyPrice + buyFee);
        assertEq(buyFee, buyPrice * 0.05 ether / 1 ether);

        (uint256 sellPrice, uint256 sellFee) = price.getSellPriceAndFee(address(flip));
        assertEq(price.getSellPriceAfterFee(address(flip)), sellPrice - sellFee);
        assertEq(sellFee, sellPrice * 0.05 ether / 1 ether);
    }
}
