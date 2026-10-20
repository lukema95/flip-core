// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IRegistry} from "../src/interfaces/IRegistry.sol";
import {IFlip} from "../src/interfaces/IFlip.sol";
import {Registry} from "../src/Registry.sol";

contract MockInvalidContract {
    function supportsInterface(bytes4) public pure returns (bool) {
        return false;
    }
}

contract MockValidContract {
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IFlip).interfaceId;
    }
}

contract RegistryTest is Test {
    Registry public registry;
    MockValidContract public mockValidContract;
    MockInvalidContract public mockInvalidContract;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        registry = new Registry();
        mockValidContract = new MockValidContract();
        mockInvalidContract = new MockInvalidContract();
    }

    function test_register_WithValidContract() public {
        registry.register(alice, address(mockValidContract));

        address[] memory creatorContracts = registry.getCreatorContracts(alice);
        assertEq(creatorContracts.length, 1);
        assertEq(creatorContracts[0], address(mockValidContract));

        address creator = registry.getContractCreator(address(mockValidContract));
        assertEq(creator, alice);
    }

    function test_register_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit IRegistry.ContractRegistered(alice, address(mockValidContract));

        registry.register(alice, address(mockValidContract));
    }

    function test_register_MultipleContracts() public {
        MockValidContract contract1 = new MockValidContract();
        MockValidContract contract2 = new MockValidContract();

        registry.register(alice, address(contract1));
        registry.register(alice, address(contract2));

        address[] memory aliceContracts = registry.getCreatorContracts(alice);
        assertEq(aliceContracts.length, 2);
        assertEq(aliceContracts[0], address(contract1));
        assertEq(aliceContracts[1], address(contract2));

        assertEq(registry.getContractCreator(address(contract1)), alice);
        assertEq(registry.getContractCreator(address(contract2)), alice);
    }

    function test_register_MultipleCreators() public {
        MockValidContract contract1 = new MockValidContract();
        MockValidContract contract2 = new MockValidContract();

        registry.register(alice, address(contract1));
        registry.register(bob, address(contract2));

        address[] memory aliceContracts = registry.getCreatorContracts(alice);
        address[] memory bobContracts = registry.getCreatorContracts(bob);

        assertEq(aliceContracts.length, 1);
        assertEq(bobContracts.length, 1);
        assertEq(aliceContracts[0], address(contract1));
        assertEq(bobContracts[0], address(contract2));

        assertEq(registry.getContractCreator(address(contract1)), alice);
        assertEq(registry.getContractCreator(address(contract2)), bob);
    }

    function test_getCreatorContracts_NonexistentCreator() public view {
        address[] memory contracts = registry.getCreatorContracts(address(0x999));
        assertEq(contracts.length, 0);
    }

    function test_getContractCreator_NonexistentContract() public view {
        address creator = registry.getContractCreator(address(0x123));
        assertEq(creator, address(0));
    }

    function test_getCreatorContracts_ZeroAddress() public view {
        address[] memory contracts = registry.getCreatorContracts(address(0));
        assertEq(contracts.length, 0);
    }

    function test_getContractCreator_ZeroAddress() public view {
        address creator = registry.getContractCreator(address(0));
        assertEq(creator, address(0));
    }

    function test_RevertWhen_ContractAlreadyRegistered() public {
        registry.register(alice, address(mockValidContract));

        vm.expectRevert(IRegistry.ContractAlreadyRegistered.selector);
        registry.register(alice, address(mockValidContract));
    }

    function test_RevertWhen_ContractAlreadyRegistered_DifferentCreator() public {
        registry.register(alice, address(mockValidContract));

        vm.expectRevert(IRegistry.ContractAlreadyRegistered.selector);
        registry.register(bob, address(mockValidContract));
    }

    function test_RevertWhen_ContractDoesNotImplementIFlipInterface() public {
        vm.expectRevert(IRegistry.ContractDoesNotImplementIFlipInterface.selector);
        registry.register(alice, address(mockInvalidContract));
    }

    function test_RevertWhen_ContractDoesNotImplementIFlipInterface_ZeroAddress() public {
        vm.expectRevert();
        registry.register(alice, address(0));
    }

    function test_register_WithZeroCreatorAddress() public {
        vm.expectEmit(true, true, false, false);
        emit IRegistry.ContractRegistered(address(0), address(mockValidContract));

        registry.register(address(0), address(mockValidContract));

        address[] memory zeroContracts = registry.getCreatorContracts(address(0));
        assertEq(zeroContracts.length, 1);
        assertEq(zeroContracts[0], address(mockValidContract));
        assertEq(registry.getContractCreator(address(mockValidContract)), address(0));
    }

    function test_register_ComplexScenario() public {
        MockValidContract contract1 = new MockValidContract();
        MockValidContract contract2 = new MockValidContract();
        MockValidContract contract3 = new MockValidContract();

        // Alice registers two contracts
        registry.register(alice, address(contract1));
        registry.register(alice, address(contract3));

        // Bob registers one contract
        registry.register(bob, address(contract2));

        // Verify Alice's contracts
        address[] memory aliceContracts = registry.getCreatorContracts(alice);
        assertEq(aliceContracts.length, 2);
        assertEq(aliceContracts[0], address(contract1));
        assertEq(aliceContracts[1], address(contract3));

        // Verify Bob's contracts
        address[] memory bobContracts = registry.getCreatorContracts(bob);
        assertEq(bobContracts.length, 1);
        assertEq(bobContracts[0], address(contract2));

        // Verify creators
        assertEq(registry.getContractCreator(address(contract1)), alice);
        assertEq(registry.getContractCreator(address(contract2)), bob);
        assertEq(registry.getContractCreator(address(contract3)), alice);
    }

    function test_fuzz_register(address creator, uint256 contractSeed) public {
        vm.assume(creator != address(0));
        vm.assume(contractSeed != 0);

        // Create a mock contract at a deterministic address
        MockValidContract mockContract = new MockValidContract();

        registry.register(creator, address(mockContract));

        address[] memory creatorContracts = registry.getCreatorContracts(creator);
        assertEq(creatorContracts.length, 1);
        assertEq(creatorContracts[0], address(mockContract));
        assertEq(registry.getContractCreator(address(mockContract)), creator);
    }
}
