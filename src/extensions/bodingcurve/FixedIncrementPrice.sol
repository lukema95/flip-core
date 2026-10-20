// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPrice} from "../../interfaces/core/IPrice.sol";
import {IStorage} from "../../interfaces/core/IStorage.sol";

/**
 * @title Fixed Increment Price Contract
 * @author @lukema95
 * @notice Fixed increment price contract: Price = initialPrice + x * a
 */
contract FixedIncrementPrice is IPrice {
    /// @notice The price increment per token (default 0.1 ether)
    uint256 public immutable PRICE_INCREMENT;

    /// @notice Errors
    error InvalidIncrement();

    /// @inheritdoc IPrice
    function getBuyPriceAfterFee(address storageContract) public view returns (uint256) {
        uint256 price = getBuyPrice(storageContract);
        uint256 fee = price * IStorage(storageContract).creatorFeePercent() / 1 ether;
        return price + fee;
    }

    /// @inheritdoc IPrice
    function getSellPriceAfterFee(address storageContract) public view returns (uint256) {
        uint256 price = getSellPrice(storageContract);
        uint256 fee = price * IStorage(storageContract).creatorFeePercent() / 1 ether;
        return price - fee;
    }

    /// @inheritdoc IPrice
    function getBuyPrice(address storageContract) public view returns (uint256) {
        return calculatePrice(storageContract, IStorage(storageContract).currentSupply());
    }

    /// @inheritdoc IPrice
    function getBuyPriceAndFee(address storageContract) public view returns (uint256, uint256) {
        uint256 price = getBuyPrice(storageContract);
        uint256 fee = price * IStorage(storageContract).creatorFeePercent() / 1 ether;
        return (price, fee);
    }

    /// @inheritdoc IPrice
    function getSellPrice(address storageContract) public view returns (uint256) {
        uint256 supply = IStorage(storageContract).currentSupply();
        return calculatePrice(storageContract, supply > 0 ? supply - 1 : 0);
    }

    /// @inheritdoc IPrice
    function getSellPriceAndFee(address storageContract) public view returns (uint256, uint256) {
        uint256 price = getSellPrice(storageContract);
        uint256 fee = price * IStorage(storageContract).creatorFeePercent() / 1 ether;
        return (price, fee);
    }

    /**
     * @notice Calculate price using fixed increment formula: Price = initialPrice + x * a
     * @param storageContract The storage contract address
     * @param supply The current supply
     * @return The calculated price
     */
    function calculatePrice(address storageContract, uint256 supply) public view virtual returns (uint256) {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        if (supply == 0) return initialPrice;

        uint256 calculatedPrice = initialPrice + (supply * PRICE_INCREMENT);

        // Apply price cap if maxPrice is set (0 = no limit)
        return maxPrice > 0 ? Math.min(calculatedPrice, maxPrice) : calculatedPrice;
    }

    /**
     * @notice Calculate price with custom increment amount
     * @param storageContract The storage contract address
     * @param supply The current supply
     * @param incrementAmount The custom increment amount per token
     * @return The calculated price
     */
    function calculatePriceWithIncrement(address storageContract, uint256 supply, uint256 incrementAmount)
        public
        view
        returns (uint256)
    {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        if (supply == 0) return initialPrice;

        uint256 calculatedPrice = initialPrice + (supply * incrementAmount);

        // Apply price cap if maxPrice is set (0 = no limit)
        return maxPrice > 0 ? Math.min(calculatedPrice, maxPrice) : calculatedPrice;
    }

    /**
     * @notice Calculate the total cost to mint n tokens from current supply
     * @param storageContract The storage contract address
     * @param currentSupply The current supply
     * @param tokensToMint The number of tokens to mint
     * @return The total cost
     */
    function calculateTotalCost(address storageContract, uint256 currentSupply, uint256 tokensToMint)
        public
        view
        returns (uint256)
    {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        uint256 totalCost = 0;
        for (uint256 i = 0; i < tokensToMint; i++) {
            uint256 tokenPrice = initialPrice + ((currentSupply + i) * PRICE_INCREMENT);
            // Apply price cap if maxPrice is set (0 = no limit)
            if (maxPrice > 0) {
                tokenPrice = Math.min(tokenPrice, maxPrice);
            }
            totalCost += tokenPrice;
        }

        return totalCost;
    }

    /**
     * @notice Calculate the total cost to mint n tokens with custom increment
     * @param storageContract The storage contract address
     * @param currentSupply The current supply
     * @param tokensToMint The number of tokens to mint
     * @param incrementAmount The custom increment amount per token
     * @return The total cost
     */
    function calculateTotalCostWithIncrement(
        address storageContract,
        uint256 currentSupply,
        uint256 tokensToMint,
        uint256 incrementAmount
    ) public view returns (uint256) {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        uint256 totalCost = 0;
        for (uint256 i = 0; i < tokensToMint; i++) {
            uint256 tokenPrice = initialPrice + ((currentSupply + i) * incrementAmount);
            // Apply price cap if maxPrice is set (0 = no limit)
            if (maxPrice > 0) {
                tokenPrice = Math.min(tokenPrice, maxPrice);
            }
            totalCost += tokenPrice;
        }

        return totalCost;
    }

    /**
     * @notice Constructor
     * @param _priceIncrement The price increment per token
     */
    constructor(uint256 _priceIncrement) {
        if (_priceIncrement == 0) revert InvalidIncrement();
        PRICE_INCREMENT = _priceIncrement;
    }
}
