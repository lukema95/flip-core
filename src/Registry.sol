// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IFlip} from "./interfaces/IFlip.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";

/**
 * @title Registry Contract
 * @author @lukema95
 * @notice Registry of all the Flip contracts
 */
contract Registry is IRegistry {
    /// @notice mapping creator to all contracts created by creator
    mapping(address => address[]) public creatorContracts;

    /// @notice mapping contract to creator
    mapping(address => address) public contractCreator;

    /// @inheritdoc IRegistry
    function register(address creator, address contractAddress) public {
        if (contractCreator[contractAddress] != address(0)) {
            revert ContractAlreadyRegistered();
        }
        // check if contract implements IFlip interface
        if (!IFlip(contractAddress).supportsInterface(type(IFlip).interfaceId)) {
            revert ContractDoesNotImplementIFlipInterface();
        }

        creatorContracts[creator].push(contractAddress);
        contractCreator[contractAddress] = creator;

        emit ContractRegistered(creator, contractAddress);
    }

    /// @inheritdoc IRegistry
    function getCreatorContracts(address creator) public view returns (address[] memory) {
        return creatorContracts[creator];
    }

    /// @inheritdoc IRegistry
    function getContractCreator(address contractAddress) public view returns (address) {
        return contractCreator[contractAddress];
    }
}
