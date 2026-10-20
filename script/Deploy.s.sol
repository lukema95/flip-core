// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {FeeVault} from "../src/core/FeeVault.sol";
import {Registry} from "../src/Registry.sol";
import {Price} from "../src/core/Price.sol";
import {Flip} from "../src/Flip.sol";
import {Factory} from "../src/Factory.sol";

/// @title Deploy
/// @notice Deploys the Flip system contracts in dependency order.
/// @dev Usage:
///   PRIVATE_KEY=0x... forge script script/Deploy.s.sol:Deploy \
///     --rpc-url "$RPC_URL" --broadcast
contract Deploy is Script {
    function run()
        external
        returns (address feeVault, address registry, address price, address flipImplementation, address factory)
    {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console.log("Deployer:", deployer);
        console.log("Chain id:", block.chainid);

        vm.startBroadcast(deployerKey);

        feeVault = address(new FeeVault());
        registry = address(new Registry());
        price = address(new Price());
        flipImplementation = address(new Flip());
        factory = address(new Factory(registry, feeVault, price, flipImplementation));

        vm.stopBroadcast();

        console.log("");
        console.log("Flip system deployed");
        console.log("  FeeVault:            ", feeVault);
        console.log("  Registry:            ", registry);
        console.log("  Price:               ", price);
        console.log("  Flip implementation: ", flipImplementation);
        console.log("  Factory:             ", factory);
        console.log("");
        console.log("Next: create a collection with Factory.createFlip(...)");
    }
}
