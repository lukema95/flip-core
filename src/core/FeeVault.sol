// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IFeeVault} from "../interfaces/core/IFeeVault.sol";

/**
 * @title FeeVault Contract
 * @author @lukema95
 * @notice FeeVault contract to store the fees
 */
contract FeeVault is IFeeVault {
    address public override admin;
    uint256 public override protocolFeePercent;

    constructor() {
        admin = msg.sender;
        protocolFeePercent = 0.2 ether; // 20%
    }

    /// @dev Modifier to check if the caller is the admin
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() internal view {
        if (msg.sender != admin) revert OnlyAdmin();
    }

    /// @inheritdoc IFeeVault
    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert Address0();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin);
    }

    /// @inheritdoc IFeeVault
    function withdrawFees(address recipient, uint256 amount) external onlyAdmin {
        if (recipient == address(0)) revert Address0();
        if (amount == 0) revert Amount0();
        if (amount > address(this).balance) revert InsufficientBalance();

        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FeeWithdrawn(recipient, amount);
    }

    receive() external payable {}
}
