// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Create4Factory} from "src/Create4Factory.sol";

/**
 * @title Deploys `env.DEPLOYED_CODE` with `env.DEPLOYED_CODE_SALT` directly through the canonical Create4Factory using the transient storage method from `addr(env.DEPLOYER_PRIVATE_KEY)`
 * @notice Only functional on networks with EIP-1153 & EIP-3855 support
 * @author dyedM1
 */
contract Create4Transient is Script {
    function run() public {
        uint256 DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
        bytes memory DEPLOYED_CODE = vm.envBytes("DEPLOYED_CODE");
        bytes32 DEPLOYED_CODE_SALT = vm.envBytes32("DEPLOYED_CODE_SALT");

        // Temporary Sepolia deployment; NOT FINAL!
        Create4Factory C4F = Create4Factory(payable(0x33A92AB4eBdf13D4D12E4bb0009c6CF7730e76d2));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        C4F.create4(DEPLOYED_CODE, DEPLOYED_CODE_SALT);

        vm.stopBroadcast();
    }
}
