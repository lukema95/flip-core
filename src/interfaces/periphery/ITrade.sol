// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrade {
    /// @notice The transfer failed error
    error TransferFailed();

    /// @notice The no tokens available error
    error NoTokensAvailable();

    /// @notice The insufficient payment error
    error InsufficientPayment();

    /// @notice The refund failed error
    error RefundFailed();

    /// @notice The not token owner error
    error NotTokenOwner();

    /// @notice Event emitted when a mint is executed
    event Minted(address indexed flipContract, address indexed to, uint256 indexed tokenId, uint256 price);

    /// @notice Event emitted when a buy is executed
    event Bought(address indexed flipContract, address indexed buyer, uint256 indexed tokenId, uint256 price);

    /// @notice Event emitted when a sell is executed
    event Sold(address indexed flipContract, address indexed seller, uint256 indexed tokenId, uint256 price);

    /// @notice Event emitted when a bulk buy is executed
    event BulkBuyExecuted(address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice);

    /// @notice Event emitted when a bulk sell is executed
    event BulkSellExecuted(
        address indexed flipContract, address indexed seller, uint256[] tokenIds, uint256 totalPrice
    );

    /// @notice Event emitted when a bulk mint is executed
    event BulkMintExecuted(address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice);

    /// @notice Event emitted when a bulk quick buy is executed
    event BulkQuickBuyExecuted(
        address indexed flipContract, address indexed buyer, uint256[] tokenIds, uint256 totalPrice
    );

    /// @notice Event emitted when a quick buy is executed
    event QuickBuyExecuted(address indexed flipContract, address indexed buyer, uint256 indexed tokenId, uint256 price);

    /// @notice Mint a NFT
    /// @param _flipContractAddress The address of the flip contract
    function mint(address _flipContractAddress) external payable;

    /// @notice Buy a NFT
    /// @param _flipContractAddress The address of the flip contract
    /// @param tokenId The ID of the NFT to buy
    function buy(address _flipContractAddress, uint256 tokenId) external payable;

    /// @notice Sell a NFT
    /// @param _flipContractAddress The address of the flip contract
    /// @param tokenId The ID of the NFT to sell
    function sell(address _flipContractAddress, uint256 tokenId) external;

    /// @notice Quick buy a NFT
    /// @param _flipContractAddress The address of the flip contract
    function quickBuy(address _flipContractAddress) external payable;

    /// @notice Bulk buy NFTs
    /// @param _flipContractAddress The address of the flip contract
    /// @param tokenIds The IDs of the NFTs to buy
    function bulkBuy(address _flipContractAddress, uint256[] memory tokenIds) external payable;

    /// @notice Bulk quick buy NFTs
    /// @param _flipContractAddress The address of the flip contract
    /// @param quantity The quantity of NFTs to buy
    function bulkQuickBuy(address _flipContractAddress, uint256 quantity) external payable;

    /// @notice Bulk sell NFTs
    /// @param _flipContractAddress The address of the flip contract
    /// @param tokenIds The IDs of the NFTs to sell
    function bulkSell(address _flipContractAddress, uint256[] memory tokenIds) external;

    /// @notice Bulk mint NFTs
    /// @param _flipContractAddress The address of the flip contract
    /// @param quantity The quantity of NFTs to mint
    function bulkMint(address _flipContractAddress, uint256 quantity) external payable;
}
