// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Storage} from "../src/core/Storage.sol";

/**
 * @title StorageSlotTest
 * @notice Simple test contract for verifying ERC7201 storage slot calculations
 */
contract StorageSlotTest is Test {
    /**
     * @notice Calculate ERC7201 storage slot according to standard
     * @param namespace The namespace string
     * @return slot The calculated storage slot
     */
    function calculateERC7201Slot(string memory namespace) public pure returns (bytes32 slot) {
        // keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff))
        bytes32 innerHash = keccak256(bytes(namespace));
        uint256 innerValue = uint256(innerHash);
        uint256 innerValueMinus1 = innerValue - 1;
        bytes32 outerHash = keccak256(abi.encode(innerValueMinus1));
        uint256 outerValue = uint256(outerHash);
        uint256 maskedValue = outerValue & ~uint256(0xff);
        slot = bytes32(maskedValue);
    }

    /**
     * @notice Test storage slot calculation for the project namespace
     */
    function test_calculateProjectStorageSlots() public view {
        string memory storageNamespace = "flip.storage.Storage";

        bytes32 storageSlot = calculateERC7201Slot(storageNamespace);

        console.log("=== Project Storage Slots ===");
        console.log("Storage namespace:", storageNamespace);
        console.log("Storage slot:", vm.toString(storageSlot));

        assertTrue(storageSlot != bytes32(0), "Storage slot should not be zero");
        assertEq(uint256(storageSlot) & 0xff, 0, "ERC7201 slot should end with 0x00");
    }

    /**
     * @notice The hardcoded storage location must match its ERC7201 namespace
     */
    function test_hardcodedSlotMatchesNamespace() public {
        StorageLocationHarness harness = new StorageLocationHarness();
        assertEq(
            harness.storageLocation(),
            calculateERC7201Slot("flip.storage.Storage"),
            "STORAGE_LOCATION does not match its ERC7201 namespace"
        );
    }

    /**
     * @notice Test ERC7201 compliance (slots should end with 0x00)
     */
    function test_erc7201Compliance() public view {
        bytes32 slot1 = calculateERC7201Slot("test.namespace.1");
        bytes32 slot2 = calculateERC7201Slot("test.namespace.2");
        bytes32 slot3 = calculateERC7201Slot("test.namespace.3");

        // Verify all slots end with 0x00
        assertEq(uint256(slot1) & 0xff, 0, "ERC7201 slot should end with 0x00");
        assertEq(uint256(slot2) & 0xff, 0, "ERC7201 slot should end with 0x00");
        assertEq(uint256(slot3) & 0xff, 0, "ERC7201 slot should end with 0x00");

        console.log("=== ERC7201 compliance test ===");
        console.log("Slot 1:", vm.toString(slot1));
        console.log("Slot 1 last byte:", uint256(slot1) & 0xff);
        console.log("Slot 2:", vm.toString(slot2));
        console.log("Slot 2 last byte:", uint256(slot2) & 0xff);
        console.log("Slot 3:", vm.toString(slot3));
        console.log("Slot 3 last byte:", uint256(slot3) & 0xff);
    }

    /**
     * @notice Test collision resistance with similar namespaces
     */
    function test_collisionResistance() public view {
        string[6] memory testNamespaces = [
            "flip.storage.Storage",
            "flip.storage.storage", // Case difference
            "flip.Storage.Storage", // First letter uppercase
            "flip.storage.Storage1", // Add number
            "flip.storage.Storag", // Less one character
            "flip.storage.Storagee" // More one character
        ];

        bytes32[6] memory slots;

        console.log("=== Collision resistance test ===");
        for (uint256 i = 0; i < testNamespaces.length; i++) {
            slots[i] = calculateERC7201Slot(testNamespaces[i]);
            console.log("Namespace:", testNamespaces[i]);
            console.log("Slot:", vm.toString(slots[i]));
        }

        // Verify all slots are different
        for (uint256 i = 0; i < slots.length; i++) {
            for (uint256 j = i + 1; j < slots.length; j++) {
                assertFalse(
                    slots[i] == slots[j],
                    string(
                        abi.encodePacked("Collision detected between: ", testNamespaces[i], " and ", testNamespaces[j])
                    )
                );
            }
        }
    }

    /**
     * @notice Generate recommended storage slots for future use
     */
    function test_generateRecommendedSlots() public view {
        string[3] memory futureNamespaces =
            ["flip.storage.Storage", "flip.permissions.AccessControl", "flip.rewards.StakingRewards"];

        console.log("=== Recommended storage slots ===");
        for (uint256 i = 0; i < futureNamespaces.length; i++) {
            bytes32 slot = calculateERC7201Slot(futureNamespaces[i]);
            console.log("Namespace:", futureNamespaces[i]);
            console.log("Recommended slot:", vm.toString(slot));
            console.log("---");
        }
    }
}

/// @dev Minimal harness exposing the internal storage location constant.
contract StorageLocationHarness is Storage {
    function storageLocation() external pure returns (bytes32) {
        return STORAGE_LOCATION;
    }
}
