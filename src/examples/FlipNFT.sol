// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Flip} from "../Flip.sol";
import {Trait} from "./Trait.sol";
/**
 * @title FlipNFT Contract
 * @author @lukema95
 * @notice FlipNFT contract is a Flip contract which implements Flip and Trait
 */

contract FlipNFT is Flip, Trait {
    using Strings for uint256;

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
        string memory uri
    ) public override initializer {
        super.initialize(
            _name,
            _symbol,
            _initialPrice,
            _maxSupply,
            _maxPrice,
            _creatorFeePercent,
            _feeVault,
            _priceContract,
            _creator,
            uri
        );
    }

    function mint() public payable override returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        super.mint();
        tokenSeed[tokenId] = block.timestamp;

        return tokenId;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        uint256 combinedSeed = uint256(keccak256(abi.encodePacked(tokenSeed[tokenId], tokenId)));
        string memory svg = generateRandomSVG(combinedSeed);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"description": "FlipNFT is the first Bonding Curve NFT.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    receive() external payable {}
}
