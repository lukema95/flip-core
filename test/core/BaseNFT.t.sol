// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Factory} from "../../src/Factory.sol";
import {Flip} from "../../src/Flip.sol";
import {Registry} from "../../src/Registry.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {IPrice} from "../../src/interfaces/core/IPrice.sol";

contract BaseNFTTest is Test {
    receive() external payable {}

    Factory public factory;
    Registry public registry;
    FeeVault public feeVault;
    Price public price;
    Flip public implementation;
    Flip public flip;

    address public alice = address(0xA11CE);
    string public constant BASE_URI = "https://example.com/metadata";

    function setUp() public {
        registry = new Registry();
        feeVault = new FeeVault();
        price = new Price();
        implementation = new Flip();
        factory = new Factory(address(registry), address(feeVault), address(price), address(implementation));
        flip = Flip(factory.createFlip("Flip", "FLIP", 0.001 ether, 1000, 0, 0.05 ether, BASE_URI));
    }

    function _mint(address to) internal returns (uint256 tokenId) {
        uint256 cost = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.deal(to, cost);
        vm.prank(to);
        tokenId = flip.mint{value: cost}();
    }

    function test_ownerIsFactory() public view {
        assertEq(flip.owner(), address(factory));
    }

    function test_contractUri() public view {
        assertEq(flip.contractURI(), string.concat(BASE_URI, "/collection.json"));
    }

    function test_tokenUri() public {
        uint256 tokenId = _mint(alice);
        assertEq(flip.tokenURI(tokenId), string.concat(BASE_URI, "/", vm.toString(tokenId), ".json"));
    }

    function test_tokenUriRevertsForUnknownToken() public {
        vm.expectRevert();
        flip.tokenURI(999);
    }

    function test_tokensOfOwner() public {
        _mint(alice);
        _mint(alice);

        uint256[] memory ids = flip.tokensOfOwner(alice);
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
    }

    function test_tokensOfOwnerInRange() public {
        _mint(alice);
        _mint(alice);
        _mint(alice);

        uint256[] memory firstTwo = flip.tokensOfOwnerInRange(alice, 0, 2);
        assertEq(firstTwo.length, 2);
        assertEq(firstTwo[1], 2);

        uint256[] memory beyondEnd = flip.tokensOfOwnerInRange(alice, 5, 1);
        assertEq(beyondEnd.length, 0);

        uint256[] memory tail = flip.tokensOfOwnerInRange(alice, 2, 5);
        assertEq(tail.length, 1);
        assertEq(tail[0], 3);
    }

    function test_ownerCanUpgradeAndStatePersists() public {
        uint256 tokenId = _mint(alice);
        Flip upgraded = new Flip();

        vm.prank(address(factory));
        flip.upgradeToAndCall(address(upgraded), "");

        assertEq(flip.totalSupply(), 1);
        assertEq(flip.ownerOf(tokenId), alice);
        assertEq(flip.contractURI(), string.concat(BASE_URI, "/collection.json"));
    }

    function test_nonOwnerCannotUpgrade() public {
        Flip upgraded = new Flip();

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this)));
        flip.upgradeToAndCall(address(upgraded), "");
    }

    function test_upgradeRevertsForCreator() public {
        Flip upgraded = new Flip();

        // the creator is the test contract itself; a random holder must not upgrade
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        flip.upgradeToAndCall(address(upgraded), "");
    }
}
