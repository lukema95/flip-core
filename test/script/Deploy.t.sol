// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {Factory} from "../../src/Factory.sol";

contract DeployScriptTest is Test {
    function test_runDeploysTheWholeSystem() public {
        vm.setEnv("PRIVATE_KEY", "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d");

        Deploy script = new Deploy();
        (address feeVault, address registry, address price, address flipImplementation, address factory) = script.run();

        assertTrue(feeVault != address(0), "feeVault");
        assertTrue(registry != address(0), "registry");
        assertTrue(price != address(0), "price");
        assertTrue(flipImplementation != address(0), "implementation");
        assertTrue(factory != address(0), "factory");

        assertTrue(feeVault != registry && registry != price && price != flipImplementation);
        assertTrue(factory != flipImplementation);

        Factory deployed = Factory(factory);
        assertEq(deployed.registry(), registry);
        assertEq(deployed.feeVault(), feeVault);
        assertEq(deployed.priceContract(), price);
        assertEq(deployed.Flip_IMPLEMENTATION(), flipImplementation);
    }
}
