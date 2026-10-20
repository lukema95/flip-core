// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IStorage} from "../interfaces/core/IStorage.sol";

/**
 * @title Storage Contract
 * @author @lukema95
 * @notice Storage contract to store the Flip data, with UUPS upgradeability support
 */
abstract contract Storage is Initializable, IStorage {
    /// @custom:storage-location erc7201:flip.storage.Storage
    struct StorageData {
        /// @notice The fee vault address
        address feeVault;
        /// @notice The price contract address
        address priceContract;
        /// @notice The initial price of the NFT collection
        uint256 initialPrice;
        /// @notice The max supply of the NFT collection
        uint256 maxSupply;
        /// @notice The max price limit of the NFT collection (0 = no limit)
        uint256 maxPrice;
        /// @notice The creator fee percent, 100% = 1 ether
        uint256 creatorFeePercent;
        /// @notice The creator of the NFT collection
        address creator;
        /// @notice The current supply of the NFT collection
        uint256 currentSupply;
        /// @notice The available tokens
        uint256[] availableTokens;
        /// @notice The index of the token
        /// @dev tokenId => index
        mapping(uint256 => uint256) tokenIndex;
        /// @notice The base URI of the NFT
        string baseURI;
    }

    // keccak256(abi.encode(uint256(keccak256("flip.storage.Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant STORAGE_LOCATION = 0xeb5d050250a195793d5c215e55811a7e5bc03a3f511fa4bdb2cdf5696dd5b000;

    function _getStorageData() private pure returns (StorageData storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    /// @notice inheritdoc IStorage
    function feeVault() public view virtual override returns (address) {
        StorageData storage $ = _getStorageData();
        return $.feeVault;
    }

    /// @notice inheritdoc IStorage
    function priceContract() public view virtual override returns (address) {
        StorageData storage $ = _getStorageData();
        return $.priceContract;
    }

    /// @notice inheritdoc IStorage
    function initialPrice() public view override returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.initialPrice;
    }

    /// @notice inheritdoc IStorage
    function maxSupply() public view override returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.maxSupply;
    }

    /// @notice inheritdoc IStorage
    function maxPrice() public view override returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.maxPrice;
    }

    /// @notice inheritdoc IStorage
    function creatorFeePercent() public view override returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.creatorFeePercent;
    }

    /// @notice inheritdoc IStorage
    function creator() public view override returns (address) {
        StorageData storage $ = _getStorageData();
        return $.creator;
    }

    /// @notice inheritdoc IStorage
    function currentSupply() public view override returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.currentSupply;
    }

    /// @notice inheritdoc IStorage
    function baseURI() public view returns (string memory) {
        StorageData storage $ = _getStorageData();
        return $.baseURI;
    }

    modifier onlyCreator() {
        _onlyCreator();
        _;
    }

    function _onlyCreator() internal view {
        StorageData storage $ = _getStorageData();
        if (msg.sender != $.creator) revert OnlyCreator();
    }

    function __Storage_init(
        uint256 _initialPrice,
        uint256 _maxSupply,
        uint256 _maxPrice,
        uint256 _creatorFeePercent,
        address _feeVault,
        address _priceContract,
        address _creator,
        string memory _uri
    ) internal onlyInitializing {
        StorageData storage $ = _getStorageData();
        $.initialPrice = _initialPrice;
        $.maxSupply = _maxSupply;
        $.maxPrice = _maxPrice;
        $.creatorFeePercent = _creatorFeePercent;
        $.creator = _creator;
        $.feeVault = _feeVault;
        $.priceContract = _priceContract;
        $.baseURI = _uri;
    }

    function setCreator(address _creator) public onlyCreator {
        if (_creator == address(0)) revert Address0();
        StorageData storage $ = _getStorageData();
        $.creator = _creator;
    }

    function setBaseURI(string memory baseUri) public onlyCreator {
        StorageData storage $ = _getStorageData();
        $.baseURI = baseUri;
    }

    /// @inheritdoc IStorage
    function getAllAvailableTokens() public view returns (uint256[] memory) {
        StorageData storage $ = _getStorageData();
        return $.availableTokens;
    }

    /// @inheritdoc IStorage
    function getAvailableTokenByIndex(uint256 index) public view returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.availableTokens[index];
    }

    /// @inheritdoc IStorage
    function getAvailableTokensPaginated(uint256 start, uint256 limit) public view returns (uint256[] memory) {
        StorageData storage $ = _getStorageData();
        require(start < $.availableTokens.length, "Start index out of bounds");
        uint256 end = Math.min(start + limit, $.availableTokens.length);
        uint256[] memory result = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = $.availableTokens[i];
        }
        return result;
    }

    /// @inheritdoc IStorage
    function getAvailableTokensCount() public view returns (uint256) {
        StorageData storage $ = _getStorageData();
        return $.availableTokens.length;
    }

    /// @notice Remove a token from the available tokens
    /// @param tokenId The ID of the token to remove
    function _removeAvailableToken(uint256 tokenId) internal {
        StorageData storage $ = _getStorageData();
        uint256 index = $.tokenIndex[tokenId];
        uint256 lastIndex = $.availableTokens.length - 1;
        uint256 lastToken = $.availableTokens[lastIndex];

        $.availableTokens[index] = lastToken;
        $.tokenIndex[lastToken] = index;

        $.availableTokens.pop();
        delete $.tokenIndex[tokenId];
    }

    /// @notice Add a token to the available tokens
    /// @param tokenId The ID of the token to add
    function _addAvailableToken(uint256 tokenId) internal {
        StorageData storage $ = _getStorageData();
        $.availableTokens.push(tokenId);
        $.tokenIndex[tokenId] = $.availableTokens.length - 1;
    }

    /// @notice Update current supply (internal helper)
    function _incrementCurrentSupply() internal {
        StorageData storage $ = _getStorageData();
        $.currentSupply++;
    }

    /// @notice Update current supply (internal helper)
    function _decrementCurrentSupply() internal {
        StorageData storage $ = _getStorageData();
        $.currentSupply--;
    }
}
