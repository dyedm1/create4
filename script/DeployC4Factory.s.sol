// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Create4Factory} from "src/Create4Factory.sol";

/**
 * @title Deploys an instance of Create4Factory
 * @author dyedM1
 */
contract DeployC4Factory is Script {
    function run() public {
        uint256 DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        new Create4Factory();

        vm.stopBroadcast();
    }
}
