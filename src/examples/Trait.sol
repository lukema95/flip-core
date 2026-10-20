// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Trait {
    using Math for uint256;
    using Strings for uint256;

    mapping(uint256 => uint256) public tokenSeed;

    // Define 16 fixed colors
    string[16] private colors = [
        "#000000", // Black
        "#FFFFFF", // White
        "#FF0000", // Red
        "#00FF00", // Green
        "#0000FF", // Blue
        "#FFFF00", // Yellow
        "#FF00FF", // Magenta
        "#00FFFF", // Cyan
        "#FFA500", // Orange
        "#800080", // Purple
        "#008000", // Dark Green
        "#800000", // Chestnut
        "#808000", // Olive
        "#008080", // Teal
        "#C0C0C0", // Silver
        "#808080" // Gray
    ];

    struct Shape {
        uint8 x;
        uint8 y;
        uint8 width;
        uint8 height;
    }

    function generateRandomSVG(uint256 tokenId) internal view returns (string memory) {
        uint256 seed = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));

        string memory bgColor = randomColor(seed);

        uint256 shapeCount = (seed % 3) + 2; // 2 to 4 shapes

        Shape[] memory shapes = new Shape[](shapeCount);
        string memory svgShapes;

        for (uint256 i = 0; i < shapeCount; i++) {
            Shape memory newShape;
            bool overlap;
            uint256 attempts = 0;

            do {
                overlap = false;
                newShape = generateShape(seed + i);

                for (uint256 j = 0; j < i; j++) {
                    if (shapesOverlap(newShape, shapes[j])) {
                        overlap = true;
                        break;
                    }
                }

                attempts++;
                seed = uint256(keccak256(abi.encodePacked(seed, attempts))); // Update seed to get new random position
                if (attempts > 10) break; // Prevent infinite loop
            } while (overlap);

            if (!overlap) {
                shapes[i] = newShape;
                svgShapes = string(abi.encodePacked(svgShapes, generateRandomShape(seed + i, newShape)));
            }
        }

        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400" viewBox="0 0 124 124" fill="none">',
                '<rect width="124" height="124" rx="24" fill="',
                bgColor,
                '"/>',
                svgShapes,
                "</svg>"
            )
        );
    }

    function generateShape(uint256 seed) internal pure returns (Shape memory) {
        uint8 padding = 24; // Equal to the radius of the rounded corners
        uint8 minSize = 25; // Approximately 1/5 of 124
        uint8 maxSize = 62; // Approximately 1/2 of 124
        uint8 size = uint8((seed % (maxSize - minSize + 1)) + minSize);

        return Shape({
            x: uint8((seed % (124 - size - 2 * padding)) + padding),
            y: uint8(((seed >> 8) % (124 - size - 2 * padding)) + padding),
            width: size,
            height: size
        });
    }

    function shapesOverlap(Shape memory a, Shape memory b) internal pure returns (bool) {
        return (a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y);
    }

    function generateRandomShape(uint256 seed, Shape memory shape) internal view returns (string memory) {
        uint256 shapeType = seed % 5;
        string memory color = randomColor(seed + 1);

        if (shapeType == 0) {
            return circleShape(shape, color);
        } else if (shapeType == 1) {
            return squareShape(shape, color);
        } else if (shapeType == 2) {
            return rectangleShape(shape, color);
        } else if (shapeType == 3) {
            return diamondShape(shape, color);
        } else {
            return trapezoidShape(shape, color);
        }
    }

    function circleShape(Shape memory shape, string memory color) internal pure returns (string memory) {
        uint8 radius = shape.width / 2;
        return string(
            abi.encodePacked(
                '<circle cx="',
                Strings.toString(shape.x + radius),
                '" cy="',
                Strings.toString(shape.y + radius),
                '" r="',
                Strings.toString(radius),
                '" fill="',
                color,
                '"/>'
            )
        );
    }

    function squareShape(Shape memory shape, string memory color) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<rect x="',
                Strings.toString(shape.x),
                '" y="',
                Strings.toString(shape.y),
                '" width="',
                Strings.toString(shape.width),
                '" height="',
                Strings.toString(shape.height),
                '" fill="',
                color,
                '"/>'
            )
        );
    }

    function rectangleShape(Shape memory shape, string memory color) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<rect x="',
                Strings.toString(shape.x),
                '" y="',
                Strings.toString(shape.y),
                '" width="',
                Strings.toString(shape.width),
                '" height="',
                Strings.toString(shape.height),
                '" fill="',
                color,
                '"/>'
            )
        );
    }

    function diamondShape(Shape memory shape, string memory color) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="',
                Strings.toString(shape.x + shape.width / 2),
                ",",
                Strings.toString(shape.y),
                " ",
                Strings.toString(shape.x),
                ",",
                Strings.toString(shape.y + shape.height / 2),
                " ",
                Strings.toString(shape.x + shape.width / 2),
                ",",
                Strings.toString(shape.y + shape.height),
                " ",
                Strings.toString(shape.x + shape.width),
                ",",
                Strings.toString(shape.y + shape.height / 2),
                '" fill="',
                color,
                '"/>'
            )
        );
    }

    function trapezoidShape(Shape memory shape, string memory color) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="',
                Strings.toString(shape.x),
                ",",
                Strings.toString(shape.y + shape.height),
                " ",
                Strings.toString(shape.x + shape.width / 2),
                ",",
                Strings.toString(shape.y),
                " ",
                Strings.toString(shape.x + shape.width),
                ",",
                Strings.toString(shape.y + shape.height),
                '" fill="',
                color,
                '"/>'
            )
        );
    }

    function randomColor(uint256 seed) internal view returns (string memory) {
        uint256 index = seed % colors.length;
        return colors[index];
    }
}
