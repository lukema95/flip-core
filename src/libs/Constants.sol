// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

library Constants {
    // Flip Factory Constants
    uint256 public constant MIN_INITIAL_PRICE = 0.0001 ether;
    uint256 public constant MAX_INITIAL_PRICE = 1 ether;
    uint256 public constant MIN_SUPPLY = 100;
    uint256 public constant MAX_SUPPLY = 1_000_000; // 1 million
    uint256 public constant MIN_CREATOR_FEE_PERCENT = 0.01 ether; // 1%
    uint256 public constant MAX_CREATOR_FEE_PERCENT = 1 ether; // 100%
}
