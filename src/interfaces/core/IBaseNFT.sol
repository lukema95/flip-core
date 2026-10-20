// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBaseNFT Interface
 * @author @lukema95
 * @notice Interface for BaseNFT contract
 */
interface IBaseNFT {
    /**
     * @notice Get the contract URI, this is the URI of the contract metadata,
     * see details in ERC7572: https://eips.ethereum.org/EIPS/eip-7572
     * @return The contract URI
     */
    function contractURI() external view returns (string memory);
}
