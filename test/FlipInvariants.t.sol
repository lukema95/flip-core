// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Flip} from "../src/Flip.sol";
import {Registry} from "../src/Registry.sol";
import {FeeVault} from "../src/core/FeeVault.sol";
import {Price} from "../src/core/Price.sol";
import {IPrice} from "../src/interfaces/core/IPrice.sol";

contract FlipInvariantsTest is Test {
    receive() external payable {}

    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public price;
    Flip public implementation;
    Flip public flip;

    address public alice = address(0xA11CE);

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        price = new Price();
        implementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(price), address(implementation));
        flip = Flip(factory.createFlip("Flip", "FLIP", 0.001 ether, 1000, 0, 0.05 ether, "https://example.com/m"));
    }

    function _mint(address to) internal returns (uint256 tokenId) {
        uint256 cost = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.deal(to, cost);
        vm.prank(to);
        tokenId = flip.mint{value: cost}();
    }

    /// @notice totalSupply must equal circulating supply plus pooled supply at all times
    function testFuzz_supplyAccounting(uint8 rawMints, uint8 rawSells) public {
        uint256 mints = bound(rawMints, 1, 6);
        uint256 sells = bound(rawSells, 0, mints);

        for (uint256 i = 0; i < mints; i++) {
            _mint(alice);
        }
        for (uint256 i = 0; i < sells; i++) {
            vm.prank(alice);
            flip.sell(i + 1);
        }

        assertEq(flip.totalSupply(), flip.currentSupply() + flip.getAvailableTokensCount());
    }

    /// @notice the curve must never quote a lower buy price as supply grows
    function testFuzz_buyPriceIsNonDecreasing(uint8 rawMints) public {
        uint256 mints = bound(rawMints, 1, 8);
        uint256 previous = IPrice(flip.priceContract()).getBuyPrice(address(flip));

        for (uint256 i = 0; i < mints; i++) {
            _mint(alice);
            uint256 current = IPrice(flip.priceContract()).getBuyPrice(address(flip));
            assertGe(current, previous);
            previous = current;
        }
    }

    /// @notice selling every minted token must leave the pool empty and the contract solvent
    function testFuzz_fullRoundTripReturnsToZero(uint8 rawMints) public {
        uint256 mints = bound(rawMints, 1, 5);
        for (uint256 i = 0; i < mints; i++) {
            _mint(alice);
        }
        for (uint256 i = 0; i < mints; i++) {
            vm.prank(alice);
            flip.sell(i + 1);
        }

        assertEq(flip.currentSupply(), 0);
        assertEq(flip.getAvailableTokensCount(), mints);
        assertEq(flip.totalSupply(), mints);
    }
}
