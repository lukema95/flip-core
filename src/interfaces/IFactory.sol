// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Factory Interface
/// @notice This interface is used to create Flip contracts
interface IFactory {
    /// @notice Error thrown when a zero address is provided
    error ZeroAddress();

    /// @notice The address of the registry contract
    function registry() external view returns (address);

    /// @notice The address of the fee vault contract
    function feeVault() external view returns (address);

    /// @notice The address of the price contract
    function priceContract() external view returns (address);

    /// @notice Event emitted when a Flip contract is created
    /// @param creator The creator of the Flip
    /// @param flipAddress The address of the Flip
    /// @param priceAddress The address of the price contract
    /// @param name The name of the Flip
    /// @param symbol The symbol of the Flip
    /// @param initialPrice The initial price of the Flip
    /// @param maxSupply The maximum supply of the Flip
    /// @param maxPrice The maximum price of the Flip
    /// @param creatorFeePercent The creator fee percent of the Flip
    /// @param baseUri The base URI of the Flip
    event FlipCreated(
        address indexed creator,
        address indexed flipAddress,
        address priceAddress,
        string name,
        string symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent,
        string baseUri
    );

    /// @notice Create a Flip contract
    /// @param name The name of the Flip
    /// @param symbol The symbol of the Flip
    /// @param initialPrice The initial price of the Flip
    /// @param maxSupply The maximum supply of the Flip
    /// @param maxPrice The maximum price of the Flip
    /// @param creatorFeePercent The creator fee percent of the Flip
    /// @param baseUri The base URI of the Flip
    function createFlip(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent,
        string memory baseUri
    ) external returns (address);

    /// @notice Calculate the address of a Flip contract
    /// @param name The name of the Flip
    /// @param symbol The symbol of the Flip
    /// @param initialPrice The initial price of the Flip
    /// @param maxSupply The maximum supply of the Flip
    /// @param maxPrice The maximum price of the Flip
    /// @param creatorFeePercent The creator fee percent of the Flip
    /// @param baseUri The base URI of the Flip
    /// @return The address of the Flip contract
    function calculateFlipAddress(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent,
        string memory baseUri
    ) external view returns (address);
}
