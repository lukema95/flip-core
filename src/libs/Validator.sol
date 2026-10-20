// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Constants} from "./Constants.sol";

library Validator {
    error EmptyString(string param);
    error InvalidPrice(uint256 price);
    error InvalidSupply(uint256 supply);
    error InvalidFeePercent(uint256 percent);

    /// @notice Validates the parameters for factory to create a Flip contract
    /// @param name The name of the Flip
    /// @param symbol The symbol of the Flip
    /// @param initialPrice The initial price of the Flip
    /// @param maxSupply The maximum supply of the Flip
    /// @param maxPrice The maximum price of the Flip
    /// @param creatorFeePercent The creator fee percent of the Flip
    function validateFlipParams(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent
    ) internal pure {
        if (bytes(name).length == 0) revert EmptyString("name");
        if (bytes(symbol).length == 0) revert EmptyString("symbol");

        if (initialPrice < Constants.MIN_INITIAL_PRICE || initialPrice > Constants.MAX_INITIAL_PRICE) {
            revert InvalidPrice(initialPrice);
        }

        if (maxSupply < Constants.MIN_SUPPLY || maxSupply > Constants.MAX_SUPPLY) {
            revert InvalidSupply(maxSupply);
        }

        if ((maxPrice < initialPrice) && (maxPrice != 0)) {
            revert InvalidPrice(maxPrice);
        }

        if (
            creatorFeePercent < Constants.MIN_CREATOR_FEE_PERCENT
                || creatorFeePercent >= Constants.MAX_CREATOR_FEE_PERCENT
        ) {
            revert InvalidFeePercent(creatorFeePercent);
        }
    }
}
