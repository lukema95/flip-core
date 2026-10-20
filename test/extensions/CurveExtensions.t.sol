// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../../src/Factory.sol";
import {Flip} from "../../src/Flip.sol";
import {Registry} from "../../src/Registry.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {LinearPrice} from "../../src/extensions/bodingcurve/LinearPrice.sol";
import {FixedIncrementPrice} from "../../src/extensions/bodingcurve/FixedIncrementPrice.sol";

contract CurveExtensionsTest is Test {
    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public price;
    Flip public implementation;
    Flip public flip;

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        price = new Price();
        implementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(price), address(implementation));
        flip = Flip(factory.createFlip("Flip", "FLIP", 0.001 ether, 1000, 0, 0.05 ether, "https://example.com/m"));
    }

    function test_linearPriceWithCustomMultiplier() public {
        LinearPrice linear = new LinearPrice(1100);

        // supply 0 returns the initial price without touching the multiplier
        assertEq(linear.calculatePriceWithMultiplier(address(flip), 0, 1500), 0.001 ether);

        uint256 custom = linear.calculatePriceWithMultiplier(address(flip), 5, 1500);
        uint256 defaultMultiplier = linear.calculatePrice(address(flip), 5);

        assertGt(custom, 0.001 ether);
        assertGt(defaultMultiplier, 0.001 ether);
    }

    function test_fixedIncrementTotalCost() public {
        FixedIncrementPrice fixedPrice = new FixedIncrementPrice(0.1 ether);

        // initialPrice 0.001 + 0.1 * i for i in [0, 1, 2]
        uint256 expected = 0.001 ether + 0.101 ether + 0.201 ether;
        assertEq(fixedPrice.calculateTotalCost(address(flip), 0, 3), expected);
    }

    function test_fixedIncrementTotalCostWithCustomIncrement() public {
        FixedIncrementPrice fixedPrice = new FixedIncrementPrice(0.1 ether);

        uint256 expected = 0.001 ether + 0.301 ether + 0.601 ether;
        assertEq(fixedPrice.calculateTotalCostWithIncrement(address(flip), 0, 3, 0.3 ether), expected);
    }

    function test_fixedIncrementTotalCostIsCapped() public {
        Flip capped = Flip(
            factory.createFlip("Capped", "CAP", 0.001 ether, 1000, 0.002 ether, 0.05 ether, "https://example.com/m")
        );
        FixedIncrementPrice fixedPrice = new FixedIncrementPrice(0.1 ether);

        // the first token is still below the cap, the rest are capped at maxPrice
        assertEq(fixedPrice.calculateTotalCost(address(capped), 0, 3), 0.001 ether + 0.002 ether + 0.002 ether);
        assertEq(
            fixedPrice.calculateTotalCostWithIncrement(address(capped), 0, 2, 0.5 ether), 0.001 ether + 0.002 ether
        );
    }
}
