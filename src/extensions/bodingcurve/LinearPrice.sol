// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPrice} from "../../interfaces/core/IPrice.sol";
import {IStorage} from "../../interfaces/core/IStorage.sol";

/**
 * @title Linear Price Contract
 * @author @lukema95
 * @notice Linear price contract with custom multiplier: Price = initialPrice + a * lastPrice
 */
contract LinearPrice is IPrice {
    /// @notice The price multiplier (in basis points, default 1100 = 1.1x)
    uint256 public immutable PRICE_MULTIPLIER;

    /// @notice Errors
    error InvalidMultiplier();

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
     * @notice Calculate price using optimized O(1) formula: Price = initialPrice * (a^(n+1) - 1) / (a - 1)
     * @param storageContract The storage contract address
     * @param supply The current supply
     * @return The calculated price
     */
    function calculatePrice(address storageContract, uint256 supply) public view virtual returns (uint256) {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        if (supply == 0) return initialPrice;

        uint256 base = 1000; // Basis points
        uint256 a = PRICE_MULTIPLIER; // a = priceMultiplier / 1000

        // Use O(1) formula: P(n) = initialPrice * (1 + a + a² + ... + aⁿ)
        // This is a geometric series with sum = initialPrice * (a^(n+1) - 1) / (a - 1)
        uint256 aPowNPlus1 = pow(a, supply + 1, base);
        uint256 price = (initialPrice * (aPowNPlus1 - pow(base, supply + 1, base))) / (a - base);

        // Apply price cap if maxPrice is set (0 = no limit)
        return maxPrice > 0 ? Math.min(price, maxPrice) : price;
    }

    /**
     * @notice Calculate price with custom multiplier using O(1) formula
     * @param storageContract The storage contract address
     * @param supply The current supply
     * @param multiplier The custom multiplier (in basis points, e.g., 1100 = 1.1x)
     * @return The calculated price
     */
    function calculatePriceWithMultiplier(address storageContract, uint256 supply, uint256 multiplier)
        public
        view
        returns (uint256)
    {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        if (supply == 0) return initialPrice;

        uint256 base = 1000; // Basis points
        uint256 a = multiplier; // a = multiplier / 1000

        // Use O(1) formula: P(n) = initialPrice * (1 + a + a² + ... + aⁿ)
        uint256 aPowNPlus1 = pow(a, supply + 1, base);
        uint256 price = (initialPrice * (aPowNPlus1 - pow(base, supply + 1, base))) / (a - base);

        // Apply price cap if maxPrice is set (0 = no limit)
        return maxPrice > 0 ? Math.min(price, maxPrice) : price;
    }

    /**
     * @notice Calculate a^b with precision handling for basis points
     * @param base The base number
     * @param exponent The exponent
     * @param precision The precision factor (1000 for basis points)
     * @return The result of base^exponent with precision handling
     */
    function pow(uint256 base, uint256 exponent, uint256 precision) internal pure returns (uint256) {
        if (exponent == 0) return precision;
        if (exponent == 1) return base;

        uint256 result = precision;
        uint256 currentBase = base;
        uint256 currentExponent = exponent;

        while (currentExponent > 0) {
            if (currentExponent & 1 == 1) {
                // Use Math.mulDiv for better precision and overflow protection
                result = Math.mulDiv(result, currentBase, precision);
            }
            // Use Math.mulDiv for better precision and overflow protection
            currentBase = Math.mulDiv(currentBase, currentBase, precision);
            currentExponent >>= 1;
        }

        return result;
    }

    /**
     * @notice Constructor
     * @param _priceMultiplier The price multiplier (in basis points)
     */
    constructor(uint256 _priceMultiplier) {
        if (_priceMultiplier < 1000 || _priceMultiplier > 2000) revert InvalidMultiplier(); // Must be >= 1.0x and < 2.0x
        PRICE_MULTIPLIER = _priceMultiplier;
    }
}
