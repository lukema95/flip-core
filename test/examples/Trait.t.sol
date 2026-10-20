// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {FlipNFT} from "../../src/examples/FlipNFT.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {Price} from "../../src/core/Price.sol";
import {IPrice} from "../../src/interfaces/core/IPrice.sol";

/// @notice Drives the SVG generator through many seeds so every shape branch is exercised.
contract TraitTest is Test {
    receive() external payable {}

    FlipNFT public flip;
    FlipNFT public implementation;
    FeeVault public feeVault;
    Price public price;

    address public alice = address(0xA11CE);

    function setUp() public {
        feeVault = new FeeVault();
        price = new Price();
        implementation = new FlipNFT();

        bytes memory initData = abi.encodeWithSelector(
            FlipNFT.initialize.selector,
            "Flip",
            "FLIP",
            0.001 ether,
            1000,
            0,
            0.01 ether,
            address(feeVault),
            address(price),
            alice,
            ""
        );
        flip = FlipNFT(payable(address(new ERC1967Proxy(address(implementation), initData))));
    }

    function _mint(address to) internal returns (uint256 tokenId) {
        uint256 cost = IPrice(flip.priceContract()).getBuyPriceAfterFee(address(flip));
        vm.deal(to, cost);
        vm.prank(to);
        tokenId = flip.mint{value: cost}();
    }

    function test_tokenUriGeneratesSvgForManySeeds() public {
        for (uint256 i = 0; i < 30; i++) {
            // vary the timestamp so tokenSeed and therefore the shape selection changes
            vm.warp(1_700_000_000 + i * 7);
            uint256 tokenId = _mint(alice);
            string memory uri = flip.tokenURI(tokenId);

            assertGt(bytes(uri).length, 0);
            assertEq(_startsWith(uri, "data:application/json;base64,"), true);
        }
    }

    function test_tokenSeedIsRecorded() public {
        vm.warp(1_234_567);
        uint256 tokenId = _mint(alice);
        assertEq(flip.tokenSeed(tokenId), 1_234_567);
    }

    function _startsWith(string memory value, string memory prefix) internal pure returns (bool) {
        bytes memory v = bytes(value);
        bytes memory p = bytes(prefix);
        if (v.length < p.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (v[i] != p[i]) return false;
        }
        return true;
    }

    function test_receiveAcceptsEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(flip).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(flip).balance, 1 ether);
    }
}
