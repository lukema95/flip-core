// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    ERC721EnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {
    ERC721HolderUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Storage} from "./Storage.sol";
import {IBaseNFT} from "../interfaces/core/IBaseNFT.sol";

/**
 * @title BaseNFT Contract
 * @author @lukema95
 * @notice Base contract for Flip which implements ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721HolderUpgradeable, OwnableUpgradeable, UUPSUpgradeable and Storage
 */
abstract contract BaseNFT is
    IBaseNFT,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721HolderUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    Storage
{
    using Strings for uint256;

    /// @notice Initialize the BaseNFT contract
    /// @param _name The name of the NFT
    /// @param _symbol The symbol of the NFT
    /// @param _initialPrice The initial price of the NFT
    /// @param _maxSupply The maximum supply of the NFT
    /// @param _maxPrice The maximum price of the NFT
    /// @param _creatorFeePercent The creator fee percent
    /// @param _feeVault The address of the fee vault
    /// @param _priceContract The address of the price contract
    /// @param _creator The creator address
    /// @param _uri The base URI for the NFT
    function __BaseNFT_init(
        string memory _name,
        string memory _symbol,
        uint256 _initialPrice,
        uint256 _maxSupply,
        uint256 _maxPrice,
        uint256 _creatorFeePercent,
        address _feeVault,
        address _priceContract,
        address _creator,
        string memory _uri
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __ERC721Holder_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // Initialize storage separately to avoid stack too deep
        _initStorage(
            _initialPrice, _maxSupply, _maxPrice, _creatorFeePercent, _feeVault, _priceContract, _creator, _uri
        );
    }

    /**
     * @notice Initialize storage parameters.
     * @dev Internal function to avoid stack too deep error.
     */
    function _initStorage(
        uint256 _initialPrice,
        uint256 _maxSupply,
        uint256 _maxPrice,
        uint256 _creatorFeePercent,
        address _feeVault,
        address _priceContract,
        address _creator,
        string memory _uri
    ) internal {
        __Storage_init(
            _initialPrice, _maxSupply, _maxPrice, _creatorFeePercent, _feeVault, _priceContract, _creator, _uri
        );
    }

    /// @inheritdoc ERC721Upgradeable
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);
        return bytes(baseURI()).length > 0 ? string.concat(baseURI(), "/", tokenId.toString(), ".json") : "";
    }

    /// @inheritdoc IBaseNFT
    function contractURI() public view returns (string memory) {
        return bytes(baseURI()).length > 0 ? string.concat(baseURI(), "/collection.json") : "";
    }

    /// @inheritdoc ERC721Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @inheritdoc ERC721Upgradeable
    function _increaseBalance(address account, uint128 amount)
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, amount);
    }

    /// @inheritdoc ERC721Upgradeable
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @notice Query all NFT tokenIds owned by an address
    /// TODO: maybe remove this function
    function tokensOfOwner(address user) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(user);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, i);
        }
        return tokenIds;
    }

    /// @notice Query NFT tokenIds owned by an address in a paginated manner
    /// @param user The address of the user
    /// @param start The starting index (0-based)
    /// @param count The maximum number of tokens to return
    /// @return tokenIds The array of tokenIds in the specified range
    /// TODO: maybe remove this function
    function tokensOfOwnerInRange(address user, uint256 start, uint256 count)
        external
        view
        returns (uint256[] memory tokenIds)
    {
        uint256 balance = balanceOf(user);
        if (start >= balance) {
            return new uint256[](0);
        }
        uint256 end = start + count;
        if (end > balance) {
            end = balance;
        }
        uint256 resultCount = end - start;
        tokenIds = new uint256[](resultCount);
        for (uint256 i = 0; i < resultCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(user, start + i);
        }
    }

    /// @notice Authorize upgrade function, only owner can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
