// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {Registry} from "../src/Registry.sol";
import {Flip} from "../src/Flip.sol";
import {FeeVault} from "../src/core/FeeVault.sol";
import {Price} from "../src/core/Price.sol";
import {IPrice} from "../src/interfaces/core/IPrice.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {Validator} from "../src/libs/Validator.sol";

contract FactoryTest is Test {
    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public priceContract;
    Flip public flipImplementation;

    address public alice = address(0x1);
    address public bob = address(0x2);

    receive() external payable {}

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        priceContract = new Price();
        flipImplementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(priceContract), address(flipImplementation));

        // Give test accounts some ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_createFlip() public {
        address contractAddress =
            factory.createFlip("Flip", "Flip", 0.001 ether, 10000, 0, 0.05 ether, "https://flip.com/image.png");
        Flip flip = Flip(contractAddress);

        address expectedAddress = factory.calculateFlipAddress(
            "Flip", "Flip", 0.001 ether, 10000, 0, 0.05 ether, "https://flip.com/image.png"
        );
        console.log("Deployed address:", address(flip));
        console.log("Expected address:", expectedAddress);
        assertEq(address(flip), expectedAddress);

        address[] memory creatorContracts = registry.getCreatorContracts(address(this));
        assertEq(creatorContracts.length, 1);
        assertEq(creatorContracts[0], expectedAddress);

        address creator = registry.getContractCreator(expectedAddress);
        assertEq(creator, address(this));

        uint256 buyPrice = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.prank(alice);
        flip.mint{value: buyPrice}();
        assertEq(flip.balanceOf(alice), 1);
    }

    function test_factoryState() public {
        assertEq(factory.registry(), address(registry));
        assertEq(factory.feeVault(), address(feeVault));
        assertEq(factory.priceContract(), address(priceContract));
        assertEq(factory.Flip_IMPLEMENTATION(), address(flipImplementation));
    }

    function test_calculateFlipAddress() public {
        address calculatedAddress =
            factory.calculateFlipAddress("Test", "TEST", 0.001 ether, 1000, 0, 0.1 ether, "https://test.com");

        address actualAddress = factory.createFlip("Test", "TEST", 0.001 ether, 1000, 0, 0.1 ether, "https://test.com");

        assertEq(calculatedAddress, actualAddress);
    }

    function test_createMultipleFlips() public {
        // Create first Flip
        address flip1 = factory.createFlip("Flip1", "Flip1", 0.001 ether, 1000, 0, 0.05 ether, "https://flip1.com");

        // Create second Flip
        address flip2 = factory.createFlip("Flip2", "Flip2", 0.002 ether, 2000, 0, 0.1 ether, "https://flip2.com");

        // Verify both are registered
        address[] memory creatorContracts = registry.getCreatorContracts(address(this));
        assertEq(creatorContracts.length, 2);
        assertTrue(creatorContracts[0] == flip1 || creatorContracts[1] == flip1);
        assertTrue(creatorContracts[0] == flip2 || creatorContracts[1] == flip2);

        // Verify different addresses
        assertFalse(flip1 == flip2);
    }

    function test_createFlipByDifferentCreators() public {
        // Create Flip by this contract
        address flip1 = factory.createFlip("Flip1", "Flip1", 0.001 ether, 1000, 0, 0.05 ether, "https://flip1.com");

        // Create Flip by alice
        vm.prank(alice);
        address flip2 = factory.createFlip("Flip2", "Flip2", 0.001 ether, 1000, 0, 0.05 ether, "https://flip2.com");

        // Verify registry entries
        address[] memory thisContracts = registry.getCreatorContracts(address(this));
        address[] memory aliceContracts = registry.getCreatorContracts(alice);

        assertEq(thisContracts.length, 1);
        assertEq(aliceContracts.length, 1);
        assertEq(thisContracts[0], flip1);
        assertEq(aliceContracts[0], flip2);

        assertEq(registry.getContractCreator(flip1), address(this));
        assertEq(registry.getContractCreator(flip2), alice);
    }

    function test_flipContractProperties() public {
        address flipAddress =
            factory.createFlip("TestFlip", "TFlip", 0.001 ether, 5000, 0, 0.03 ether, "https://testflip.com");

        Flip flip = Flip(flipAddress);

        // Test basic properties
        assertEq(flip.name(), "TestFlip");
        assertEq(flip.symbol(), "TFlip");
        assertEq(flip.initialPrice(), 0.001 ether);
        assertEq(flip.maxSupply(), 5000);
        assertEq(flip.creatorFeePercent(), 0.03 ether);
        assertEq(flip.creator(), address(this));
        assertEq(flip.feeVault(), address(feeVault));
        assertEq(flip.priceContract(), address(priceContract));
        assertEq(flip.totalSupply(), 0);
        assertEq(flip.currentSupply(), 0);
    }

    function test_priceCalculation() public {
        address flipAddress =
            factory.createFlip("PriceTest", "PRICE", 0.001 ether, 1000, 0, 0.1 ether, "https://price.com");

        Flip flip = Flip(flipAddress);

        // Test initial price
        uint256 initialBuyPrice = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        assertGt(initialBuyPrice, 0.001 ether); // Should be initial price + fee

        // Mint one NFT and check price increase
        vm.prank(alice);
        flip.mint{value: initialBuyPrice}();

        uint256 secondBuyPrice = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        assertGt(secondBuyPrice, initialBuyPrice); // Price should increase

        assertEq(flip.totalSupply(), 1);
        assertEq(flip.currentSupply(), 1);
    }

    function test_invalidParametersShouldRevert() public {
        // Test empty name
        vm.expectRevert(abi.encodeWithSelector(Validator.EmptyString.selector, "name"));
        factory.createFlip("", "Flip", 0.001 ether, 1000, 0, 0.05 ether, "https://flip.com");

        // Test empty symbol
        vm.expectRevert(abi.encodeWithSelector(Validator.EmptyString.selector, "symbol"));
        factory.createFlip("Flip", "", 0.001 ether, 1000, 0, 0.05 ether, "https://flip.com");

        // Test invalid initial price (too low)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidPrice.selector, 0.00001 ether));
        factory.createFlip("Flip", "Flip", 0.00001 ether, 1000, 0, 0.05 ether, "https://flip.com");

        // Test invalid initial price (too high)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidPrice.selector, 2 ether));
        factory.createFlip("Flip", "Flip", 2 ether, 1000, 0, 0.05 ether, "https://flip.com");

        // Test invalid supply (too low)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidSupply.selector, 50));
        factory.createFlip("Flip", "Flip", 0.001 ether, 50, 0, 0.05 ether, "https://flip.com");

        // Test invalid supply (too high)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidSupply.selector, 2000000));
        factory.createFlip("Flip", "Flip", 0.001 ether, 2000000, 0, 0.05 ether, "https://flip.com");

        // Test invalid creator fee percent (too low)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidFeePercent.selector, 0.005 ether));
        factory.createFlip("Flip", "Flip", 0.001 ether, 1000, 0, 0.005 ether, "https://flip.com");

        // Test invalid creator fee percent (too high)
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidFeePercent.selector, 1.1 ether));
        factory.createFlip("Flip", "Flip", 0.001 ether, 1000, 0, 1.1 ether, "https://flip.com");
    }

    function test_eventEmission() public {
        // Calculate the expected address first
        address expectedAddress =
            factory.calculateFlipAddress("EventTest", "EVENT", 0.001 ether, 1000, 0, 0.05 ether, "https://event.com");

        // Test FlipCreated event
        vm.expectEmit(true, true, false, false);
        emit IFactory.FlipCreated(
            address(this),
            expectedAddress,
            address(priceContract),
            "EventTest",
            "EVENT",
            0.001 ether,
            1000,
            0,
            0.05 ether,
            "https://event.com"
        );

        factory.createFlip("EventTest", "EVENT", 0.001 ether, 1000, 0, 0.05 ether, "https://event.com");
    }

    function test_deterministic_addresses() public {
        // Same parameters should produce same calculated address
        address calc1 =
            factory.calculateFlipAddress("Same", "SAME", 0.001 ether, 1000, 0, 0.05 ether, "https://same.com");

        address calc2 =
            factory.calculateFlipAddress("Same", "SAME", 0.001 ether, 1000, 0, 0.05 ether, "https://same.com");

        assertEq(calc1, calc2);

        // Different parameters should produce different addresses
        address calc3 = factory.calculateFlipAddress(
            "Different", "DIFF", 0.001 ether, 1000, 0, 0.05 ether, "https://different.com"
        );

        assertFalse(calc1 == calc3);
    }

    function test_constructorRevertsWhenRegistryIsZero() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(address(0), address(feeVault), address(priceContract), address(flipImplementation));
    }

    function test_constructorRevertsWhenFeeVaultIsZero() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(address(registry), address(0), address(priceContract), address(flipImplementation));
    }

    function test_constructorRevertsWhenPriceIsZero() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(address(registry), address(feeVault), address(0), address(flipImplementation));
    }

    function test_constructorRevertsWhenImplementationIsZero() public {
        vm.expectRevert(IFactory.ZeroAddress.selector);
        new Factory(address(registry), address(feeVault), address(priceContract), address(0));
    }

    function test_invalidMaxPriceShouldRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Validator.InvalidPrice.selector, 0.0001 ether));
        factory.createFlip("Flip", "FLIP", 0.001 ether, 1000, 0.0001 ether, 0.05 ether, "https://example.com/m");
    }
}
