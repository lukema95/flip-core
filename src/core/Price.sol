// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPrice} from "../interfaces/core/IPrice.sol";
import {IStorage} from "../interfaces/core/IStorage.sol";

/**
 * @title Price Contract
 * @author @lukema95
 * @notice Price contract to calculate the price of NFTs, it's a singleton contract
 */
contract Price is IPrice {
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

    /// @inheritdoc IPrice
    function calculatePrice(address storageContract, uint256 supply) public view virtual returns (uint256) {
        uint256 initialPrice = IStorage(storageContract).initialPrice();
        uint256 maxSupply = IStorage(storageContract).maxSupply();
        uint256 maxPrice = IStorage(storageContract).maxPrice();

        if (supply == 0) return initialPrice;

        // Calculate price using Math library for safety
        uint256 price = initialPrice
            + (initialPrice * 2 * Math.sqrt(100 * supply * maxSupply) * Math.sqrt(10000 * supply * supply))
            / (maxSupply * maxSupply);

        // Apply price cap if maxPrice is set (0 = no limit)
        return maxPrice > 0 ? Math.min(price, maxPrice) : price;
    }
}
