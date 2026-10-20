// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IPrice} from "./interfaces/core/IPrice.sol";
import {IFeeVault} from "./interfaces/core/IFeeVault.sol";
import {IFlip} from "./interfaces/IFlip.sol";
import {BaseNFT} from "./core/BaseNFT.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Flip
 * @author @lukema95
 * @notice Flip collection instance, implements IFlip interface
 */
contract Flip is BaseNFT, IFlip {
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initialPrice,
        uint256 _maxSupply,
        uint256 _maxPrice,
        uint256 _creatorFeePercent,
        address _feeVault,
        address _priceContract,
        address _creator,
        string memory baseUri
    ) public virtual initializer {
        __BaseNFT_init(
            _name,
            _symbol,
            _initialPrice,
            _maxSupply,
            _maxPrice,
            _creatorFeePercent,
            _feeVault,
            _priceContract,
            _creator,
            baseUri
        );
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        _onlyTokenOwner(tokenId);
        _;
    }

    function _onlyTokenOwner(uint256 tokenId) internal view {
        if (ownerOf(tokenId) != _msgSender()) revert NotOwner();
    }

    modifier onlyTokenOnSale(uint256 tokenId) {
        _onlyTokenOnSale(tokenId);
        _;
    }

    function _onlyTokenOnSale(uint256 tokenId) internal view {
        if (ownerOf(tokenId) != address(this)) revert NotOnSale();
    }

    /// @inheritdoc IFlip
    function mint() public payable virtual returns (uint256) {
        if (totalSupply() >= maxSupply()) revert OverMaxSupply();

        (uint256 price, uint256 creatorFee) = IPrice(priceContract()).getBuyPriceAndFee(address(this));
        if (msg.value < price + creatorFee) revert InsufficientPayment();

        uint256 tokenId = totalSupply() + 1;

        _safeMint(msg.sender, tokenId);
        _incrementCurrentSupply();

        emit TokenMinted(msg.sender, tokenId, price, creatorFee);

        distributeFee(creatorFee);

        _refundExcess(price + creatorFee);

        return tokenId;
    }

    /// @inheritdoc IFlip
    function buy(uint256 tokenId) public payable onlyTokenOnSale(tokenId) {
        (uint256 price, uint256 creatorFee) = IPrice(priceContract()).getBuyPriceAndFee(address(this));
        if (msg.value < price + creatorFee) revert InsufficientPayment();

        _transfer(address(this), msg.sender, tokenId);

        _removeAvailableToken(tokenId);
        _incrementCurrentSupply();

        emit TokenBought(msg.sender, tokenId, price, creatorFee);

        distributeFee(creatorFee);

        _refundExcess(price + creatorFee);
    }

    /// @inheritdoc IFlip
    function sell(uint256 tokenId) public onlyTokenOwner(tokenId) {
        (uint256 price, uint256 creatorFee) = IPrice(priceContract()).getSellPriceAndFee(address(this));

        _transfer(_msgSender(), address(this), tokenId);
        _addAvailableToken(tokenId);
        _decrementCurrentSupply();

        emit TokenSold(_msgSender(), tokenId, price, creatorFee);

        /// solhint-disable-next-line avoid-low-level-calls
        (bool sentToSeller,) = _msgSender().call{value: price - creatorFee}("");
        if (!sentToSeller) revert TransferFailed();

        distributeFee(creatorFee);
    }

    /// @inheritdoc IFlip
    function isOnSale(uint256 tokenId) public view returns (bool) {
        return ownerOf(tokenId) == address(this);
    }

    function distributeFee(uint256 fee) internal {
        uint256 protocolFee = (fee * IFeeVault(feeVault()).protocolFeePercent()) / 1 ether;
        uint256 creatorFee = fee - protocolFee;

        /// solhint-disable-next-line avoid-low-level-calls
        (bool success,) = creator().call{value: creatorFee}("");
        if (!success) revert TransferFailed();

        (bool successProtocol,) = feeVault().call{value: protocolFee}("");
        if (!successProtocol) revert TransferFailed();
    }

    function _refundExcess(uint256 price) internal {
        uint256 refundAmount = msg.value - price;
        if (refundAmount > 0) {
            /// solhint-disable-next-line avoid-low-level-calls
            (bool success,) = _msgSender().call{value: refundAmount}("");
            if (!success) revert RefundFailed();
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseNFT, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId) || interfaceId == type(IFlip).interfaceId;
    }
}
