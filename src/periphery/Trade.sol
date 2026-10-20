// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IPrice} from "../interfaces/core/IPrice.sol";
import {ITrade} from "../interfaces/periphery/ITrade.sol";
import {Flip} from "../Flip.sol";

/**
 * @title Trade Contract
 * @author @lukema95
 * @notice Trade contract for Flip NFTs
 */
contract Trade is ITrade, ERC721Holder {
    /// @inheritdoc ITrade
    function mint(address _flipContractAddress) external payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
        uint256 tokenId = flipContract.mint{value: msg.value}();
        flipContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Minted(_flipContractAddress, msg.sender, tokenId, price);
    }

    /// @inheritdoc ITrade
    function buy(address _flipContractAddress, uint256 tokenId) external payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
        flipContract.buy{value: msg.value}(tokenId);
        flipContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Bought(_flipContractAddress, msg.sender, tokenId, price);
    }

    /// @inheritdoc ITrade
    function sell(address _flipContractAddress, uint256 tokenId) external {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 price = priceContract.getSellPriceAfterFee(_flipContractAddress);
        flipContract.safeTransferFrom(msg.sender, address(this), tokenId);
        flipContract.sell(tokenId);

        (bool success,) = msg.sender.call{value: price}("");
        if (!success) revert TransferFailed();

        emit Sold(_flipContractAddress, msg.sender, tokenId, price);
    }

    /// @inheritdoc ITrade
    function quickBuy(address _flipContractAddress) public payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        if (flipContract.getAvailableTokensCount() == 0) revert NoTokensAvailable();
        uint256 tokenId = flipContract.getAvailableTokenByIndex(flipContract.getAvailableTokensCount() - 1);
        uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
        flipContract.buy{value: price}(tokenId);
        flipContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit QuickBuyExecuted(_flipContractAddress, msg.sender, tokenId, price);
    }

    /// @inheritdoc ITrade
    function bulkBuy(address _flipContractAddress, uint256[] calldata tokenIds) external payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
            totalPrice += price;
            if (msg.value < totalPrice) revert InsufficientPayment();
            flipContract.buy{value: price}(tokenIds[i]);
            flipContract.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
        }

        emit BulkBuyExecuted(_flipContractAddress, msg.sender, tokenIds, totalPrice);

        // Refund excess ETH
        uint256 excess = msg.value - totalPrice;
        if (excess > 0) {
            (bool success,) = msg.sender.call{value: excess}("");
            if (!success) revert RefundFailed();
        }
    }

    /// @inheritdoc ITrade
    function bulkQuickBuy(address _flipContractAddress, uint256 quantity) external payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 totalPrice = 0;
        uint256 availableTokensCount = flipContract.getAvailableTokensCount();
        uint256[] memory tokenIds = new uint256[](quantity);
        if (availableTokensCount < quantity) revert NoTokensAvailable();
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = flipContract.getAvailableTokenByIndex(availableTokensCount - 1);
            uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
            totalPrice += price;
            if (msg.value < totalPrice) revert InsufficientPayment();
            flipContract.buy{value: price}(tokenId);
            flipContract.safeTransferFrom(address(this), msg.sender, tokenId);
            availableTokensCount--;
            tokenIds[i] = tokenId;
        }

        emit BulkQuickBuyExecuted(_flipContractAddress, msg.sender, tokenIds, totalPrice);

        // Refund excess ETH
        uint256 excess = msg.value - totalPrice;
        if (excess > 0) {
            (bool success,) = msg.sender.call{value: excess}("");
            if (!success) revert RefundFailed();
        }
    }

    /// @inheritdoc ITrade
    function bulkSell(address _flipContractAddress, uint256[] calldata tokenIds) external {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 totalPrice = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (flipContract.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
            uint256 price = priceContract.getSellPriceAfterFee(_flipContractAddress);
            totalPrice += price;

            flipContract.safeTransferFrom(msg.sender, address(this), tokenId);
            flipContract.sell(tokenId);
        }

        emit BulkSellExecuted(_flipContractAddress, msg.sender, tokenIds, totalPrice);

        (bool success,) = msg.sender.call{value: totalPrice}("");
        if (!success) revert TransferFailed();
    }

    /// @inheritdoc ITrade
    function bulkMint(address _flipContractAddress, uint256 quantity) external payable {
        Flip flipContract = Flip(_flipContractAddress);
        IPrice priceContract = IPrice(flipContract.priceContract());
        uint256 totalPrice = 0;
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 price = priceContract.getBuyPriceAfterFee(_flipContractAddress);
            totalPrice += price;
            if (msg.value < totalPrice) revert InsufficientPayment();
            uint256 tokenId = flipContract.mint{value: price}();
            flipContract.safeTransferFrom(address(this), msg.sender, tokenId);
            tokenIds[i] = tokenId;
        }

        emit BulkMintExecuted(_flipContractAddress, msg.sender, tokenIds, totalPrice);

        // Refund excess ETH
        uint256 excess = msg.value - totalPrice;
        if (excess > 0) {
            (bool success,) = msg.sender.call{value: excess}("");
            if (!success) revert RefundFailed();
        }
    }

    receive() external payable {}
}
