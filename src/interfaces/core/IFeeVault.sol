// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFeeVault Interface
 * @author @lukema95
 * @notice Interface for FeeVault contract
 */
interface IFeeVault {
    /// @notice The only admin error
    error OnlyAdmin();

    /// @notice The address cannot be 0 error
    error Address0();

    /// @notice The amount cannot be 0 error
    error Amount0();

    /// @notice The insufficient balance error
    error InsufficientBalance();

    /// @notice The transfer failed error
    error TransferFailed();

    /// @notice Get the admin address
    /// @return The address of the admin
    function admin() external view returns (address);

    /// @notice Get the protocol fee percent
    /// @return The protocol fee percent
    function protocolFeePercent() external view returns (uint256);

    /// @notice Event emitted when the admin is changed
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /// @notice Event emitted when fees are withdrawn
    event FeeWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Set the admin
    function setAdmin(address newAdmin) external;

    /// @notice Withdraw fees
    function withdrawFees(address recipient, uint256 amount) external;
}
