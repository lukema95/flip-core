// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {FeeVault} from "../../src/core/FeeVault.sol";
import {IFeeVault} from "../../src/interfaces/core/IFeeVault.sol";

/// @dev Recipient that rejects ETH transfers.
contract RejectingRecipient {
    receive() external payable {
        revert("no ETH");
    }
}

contract FeeVaultTest is Test {
    receive() external payable {}

    FeeVault public feeVault;

    address public admin = address(this);
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event FeeWithdrawn(address indexed recipient, uint256 amount);

    function setUp() public {
        feeVault = new FeeVault();
        vm.deal(address(this), 10 ether);
    }

    function test_constructorSetsAdminAndFee() public view {
        assertEq(feeVault.admin(), admin);
        assertEq(feeVault.protocolFeePercent(), 0.2 ether);
    }

    function test_receiveAcceptsEth() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool ok,) = address(feeVault).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(feeVault).balance, 1 ether);
    }

    function test_setAdmin() public {
        vm.expectEmit(true, true, false, false);
        emit AdminChanged(admin, alice);

        feeVault.setAdmin(alice);

        assertEq(feeVault.admin(), alice);
    }

    function test_setAdminRevertsForNonAdmin() public {
        vm.prank(alice);
        vm.expectRevert(IFeeVault.OnlyAdmin.selector);
        feeVault.setAdmin(alice);
    }

    function test_setAdminRevertsForZeroAddress() public {
        vm.expectRevert(IFeeVault.Address0.selector);
        feeVault.setAdmin(address(0));
    }

    function test_withdrawFees() public {
        vm.deal(address(feeVault), 5 ether);
        uint256 before = alice.balance;

        vm.expectEmit(true, false, false, true);
        emit FeeWithdrawn(alice, 2 ether);

        feeVault.withdrawFees(alice, 2 ether);

        assertEq(alice.balance, before + 2 ether);
        assertEq(address(feeVault).balance, 3 ether);
    }

    function test_withdrawFeesRevertsForNonAdmin() public {
        vm.deal(address(feeVault), 1 ether);
        vm.prank(alice);
        vm.expectRevert(IFeeVault.OnlyAdmin.selector);
        feeVault.withdrawFees(alice, 1 ether);
    }

    function test_withdrawFeesRevertsForZeroRecipient() public {
        vm.expectRevert(IFeeVault.Address0.selector);
        feeVault.withdrawFees(address(0), 1 ether);
    }

    function test_withdrawFeesRevertsForZeroAmount() public {
        vm.expectRevert(IFeeVault.Amount0.selector);
        feeVault.withdrawFees(alice, 0);
    }

    function test_withdrawFeesRevertsWhenAmountExceedsBalance() public {
        vm.deal(address(feeVault), 1 ether);
        vm.expectRevert(IFeeVault.InsufficientBalance.selector);
        feeVault.withdrawFees(alice, 2 ether);
    }

    function test_withdrawFeesRevertsWhenRecipientRejectsEth() public {
        RejectingRecipient recipient = new RejectingRecipient();
        vm.deal(address(feeVault), 1 ether);

        vm.expectRevert(IFeeVault.TransferFailed.selector);
        feeVault.withdrawFees(address(recipient), 1 ether);
    }

    function test_withdrawFeesEmitsAndClearsBalance() public {
        vm.deal(address(feeVault), 3 ether);
        feeVault.withdrawFees(admin, 3 ether);
        assertEq(address(feeVault).balance, 0);
    }
}
