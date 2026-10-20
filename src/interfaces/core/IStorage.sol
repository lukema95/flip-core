// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStorage Interface
 * @author @lukema95
 * @notice Interface for Storage contract
 */
interface IStorage {
    /// @notice The only creator error
    error OnlyCreator();

    /// @notice The address 0 error
    error Address0();

    /// @notice Get the fee vault address
    /// @return The fee vault address
    function feeVault() external view returns (address);

    /// @notice Get the price contract address
    /// @return The price contract address
    function priceContract() external view returns (address);

    /// @notice Get the initial price
    /// @return The initial price
    function initialPrice() external view returns (uint256);

    /// @notice Get the max supply
    /// @return The max supply
    function maxSupply() external view returns (uint256);

    /// @notice Get the max price limit
    /// @return The max price limit (0 = no limit)
    function maxPrice() external view returns (uint256);

    /// @notice Get the creator fee percent
    /// @return The creator fee percent
    function creatorFeePercent() external view returns (uint256);

    /// @notice Get the creator
    /// @return The creator
    function creator() external view returns (address);

    /// @notice Get the current supply
    /// @return The current supply
    function currentSupply() external view returns (uint256);

    /// @notice Get all available tokens
    /// @return The available tokens
    function getAllAvailableTokens() external view returns (uint256[] memory);

    /// @notice Get the available token by index
    /// @param index The index of the token
    /// @return The token ID
    function getAvailableTokenByIndex(uint256 index) external view returns (uint256);

    /// @notice Get the available tokens paginated
    /// @param start The start index
    /// @param limit The limit of tokens to return
    /// @return The token IDs
    function getAvailableTokensPaginated(uint256 start, uint256 limit) external view returns (uint256[] memory);

    /// @notice Get the available tokens count
    /// @return The number of available tokens
    function getAvailableTokensCount() external view returns (uint256);
}
