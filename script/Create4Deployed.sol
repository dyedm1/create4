// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Create4Factory} from "src/Create4Factory.sol";

/**
 * @title Deploys the code present at `env.DEPLOYED_CODE_ADDRESS` with `env.DEPLOYED_CODE_SALT` through the canonical Create4Factory using the deployed code method from `addr(env.DEPLOYER_PRIVATE_KEY)`
 * @notice Only functional on networks with EIP-3855 support
 * @author dyedM1
 */
contract Create4Deployed is Script {
    function run() public {
        uint256 DEPLOYER_PRIVATE_KEY = vm.envUint("DEPLOYER_PRIVATE_KEY");
        bytes memory INIT_CODE = vm.envBytes("INIT_CODE");
        bytes32 DEPLOYED_CODE_SALT = vm.envBytes32("DEPLOYED_CODE_SALT");

        // Temporary Sepolia deployment; NOT FINAL!
        Create4Factory C4F = Create4Factory(payable(0x33A92AB4eBdf13D4D12E4bb0009c6CF7730e76d2));

        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address deployedCode;
        assembly {
            deployedCode := create(0, add(INIT_CODE, 0x20), mload(INIT_CODE))
        }

        C4F.create4(deployedCode, DEPLOYED_CODE_SALT);

        vm.stopBroadcast();
    }
}
