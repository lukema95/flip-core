// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPrice Interface
 * @author @lukema95
 * @notice Interface for Price contract
 */
interface IPrice {
    /**
     * @notice Get the buy price including creator fee
     * @return The total price including fee
     */
    function getBuyPriceAfterFee(address storageContract) external view returns (uint256);

    /**
     * @notice Get the sell price after deducting creator fee
     * @return The final price after fee deduction
     */
    function getSellPriceAfterFee(address storageContract) external view returns (uint256);

    /**
     * @notice Get the current buy price without fee
     * @return The base buy price
     */
    function getBuyPrice(address storageContract) external view returns (uint256);

    /**
     * @notice Get the current buy price and creator fee
     * @return The base buy price and creator fee
     */
    function getBuyPriceAndFee(address storageContract) external view returns (uint256, uint256);

    /**
     * @notice Get the current sell price without fee
     * @return The base sell price
     */
    function getSellPrice(address storageContract) external view returns (uint256);

    /**
     * @notice Get the current sell price and creator fee
     * @return The base sell price and creator fee
     */
    function getSellPriceAndFee(address storageContract) external view returns (uint256, uint256);

    /**
     * @notice Calculate the price based on current supply
     * @param supply The supply amount to calculate price for
     * @return The calculated price
     */
    function calculatePrice(address storageContract, uint256 supply) external view returns (uint256);
}
