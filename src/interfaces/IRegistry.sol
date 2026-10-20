// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Registry Interface
/// @notice This interface is used to register Flip contracts
interface IRegistry {
    /// @notice Event emitted when a contract is registered
    event ContractRegistered(address creator, address contractAddress);

    /// @notice Error emitted when a contract is already registered
    error ContractAlreadyRegistered();

    /// @notice Error emitted when a contract does not implement IFlip interface
    error ContractDoesNotImplementIFlipInterface();

    /// @notice Register a contract
    /// @param creator The creator of the contract
    /// @param contractAddress The address of the contract
    function register(address creator, address contractAddress) external;

    /// @notice Get all contracts created by a creator
    /// @param creator The creator of the contracts
    /// @return An array of contract addresses
    function getCreatorContracts(address creator) external view returns (address[] memory);

    /// @notice Get the creator of a contract
    /// @param contractAddress The address of the contract
    /// @return The creator of the contract
    function getContractCreator(address contractAddress) external view returns (address);
}
