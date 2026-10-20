// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 *
 *                                                                     *
 *                          ⭐️  F L I P  ⭐️                             *
 *                                                                     *
 *            bonding-curve NFT AMM · EIP-1967 proxy factory            *
 *                                                                     *
 *
 */
import {Flip} from "./Flip.sol";
import {IRegistry} from "./interfaces/IRegistry.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {Validator} from "./libs/Validator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Factory Contract
 * @author @lukema95
 * @notice Factory contract for creating Flip contracts
 */
contract Factory is IFactory {
    /// @dev Internal bundle of the collection parameters, kept off the stack.
    struct CreateParams {
        string name;
        string symbol;
        uint256 initialPrice;
        uint256 maxSupply;
        uint256 maxPrice;
        uint256 creatorFeePercent;
        string baseUri;
    }

    address public override registry;
    address public override feeVault;
    address public override priceContract;
    address public immutable Flip_IMPLEMENTATION;

    constructor(address _registry, address _feeVault, address _priceContract, address _flipImplementation) {
        if (
            _registry == address(0) || _feeVault == address(0) || _priceContract == address(0)
                || _flipImplementation == address(0)
        ) {
            revert ZeroAddress();
        }

        registry = _registry;
        feeVault = _feeVault;
        priceContract = _priceContract;
        Flip_IMPLEMENTATION = _flipImplementation;
    }

    /// @dev Modifier to validate the parameters for factory to create a Flip contract
    modifier validateParams(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent
    ) {
        Validator.validateFlipParams(name, symbol, initialPrice, maxSupply, maxPrice, creatorFeePercent);
        _;
    }

    /// @inheritdoc IFactory
    function createFlip(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent,
        string memory baseUri
    ) external validateParams(name, symbol, initialPrice, maxSupply, maxPrice, creatorFeePercent) returns (address) {
        CreateParams memory params;
        params.name = name;
        params.symbol = symbol;
        params.initialPrice = initialPrice;
        params.maxSupply = maxSupply;
        params.maxPrice = maxPrice;
        params.creatorFeePercent = creatorFeePercent;
        params.baseUri = baseUri;

        address creator = msg.sender;
        bytes memory initData = _initData(params, creator);
        bytes32 salt = getSalt(params);

        ERC1967Proxy proxy = new ERC1967Proxy{salt: salt}(Flip_IMPLEMENTATION, initData);
        address flipAddress = address(proxy);

        _emitFlipCreated(creator, flipAddress, params);
        IRegistry(registry).register(creator, flipAddress);
        return flipAddress;
    }

    /// @inheritdoc IFactory
    function calculateFlipAddress(
        string memory name,
        string memory symbol,
        uint256 initialPrice,
        uint256 maxSupply,
        uint256 maxPrice,
        uint256 creatorFeePercent,
        string memory baseUri
    ) public view returns (address flipAddress) {
        CreateParams memory params;
        params.name = name;
        params.symbol = symbol;
        params.initialPrice = initialPrice;
        params.maxSupply = maxSupply;
        params.maxPrice = maxPrice;
        params.creatorFeePercent = creatorFeePercent;
        params.baseUri = baseUri;

        bytes memory initData = _initData(params, msg.sender);
        bytes memory proxyInitParams = abi.encode(Flip_IMPLEMENTATION, initData);
        bytes32 salt = getSalt(params);

        flipAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            salt,
                            keccak256(abi.encodePacked(type(ERC1967Proxy).creationCode, proxyInitParams))
                        )
                    )
                )
            )
        );
    }

    function getSalt(CreateParams memory params) internal pure returns (bytes32) {
        return keccak256(abi.encode(params.name, params.symbol, params.initialPrice, params.maxSupply, params.maxPrice));
    }

    function _initData(CreateParams memory params, address creator) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            Flip.initialize.selector,
            params.name,
            params.symbol,
            params.initialPrice,
            params.maxSupply,
            params.maxPrice,
            params.creatorFeePercent,
            feeVault,
            priceContract,
            creator,
            params.baseUri
        );
    }

    function _emitFlipCreated(address creator, address flipAddress, CreateParams memory params) internal {
        emit FlipCreated(
            creator,
            flipAddress,
            priceContract,
            params.name,
            params.symbol,
            params.initialPrice,
            params.maxSupply,
            params.maxPrice,
            params.creatorFeePercent,
            params.baseUri
        );
    }
}
