// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Factory} from "../../src/Factory.sol";
import {Flip} from "../../src/Flip.sol";
import {Registry} from "../../src/Registry.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {IPrice} from "../../src/interfaces/core/IPrice.sol";
import {IStorage} from "../../src/interfaces/core/IStorage.sol";

contract StorageTest is Test {
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

    function test_setBaseUriByCreator() public {
        flip.setBaseURI("ipfs://metadata");

        assertEq(flip.baseURI(), "ipfs://metadata");
        assertEq(flip.contractURI(), "ipfs://metadata/collection.json");
    }

    function test_setBaseUriRevertsForNonCreator() public {
        vm.prank(alice);
        vm.expectRevert(IStorage.OnlyCreator.selector);
        flip.setBaseURI("ipfs://metadata");
    }

    function test_setCreatorRevertsForZeroAddress() public {
        vm.expectRevert(IStorage.Address0.selector);
        flip.setCreator(address(0));
    }

    function test_availableTokensPagination() public {
        _mint(alice);
        _mint(alice);
        _mint(alice);

        vm.startPrank(alice);
        flip.sell(1);
        flip.sell(2);
        vm.stopPrank();

        assertEq(flip.getAvailableTokensCount(), 2);

        uint256[] memory all = flip.getAllAvailableTokens();
        assertEq(all.length, 2);

        uint256[] memory page = flip.getAvailableTokensPaginated(0, 5);
        assertEq(page.length, 2);
        assertEq(page[0], flip.getAvailableTokenByIndex(0));

        uint256[] memory tail = flip.getAvailableTokensPaginated(1, 1);
        assertEq(tail.length, 1);
        assertEq(tail[0], flip.getAvailableTokenByIndex(1));
    }

    function test_availableTokensPaginationRevertsOutOfBounds() public {
        _mint(alice);
        vm.prank(alice);
        flip.sell(1);

        vm.expectRevert(bytes("Start index out of bounds"));
        flip.getAvailableTokensPaginated(1, 1);
    }
}
