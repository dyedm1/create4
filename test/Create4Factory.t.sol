// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

import {Create4Factory} from "src/Create4Factory.sol";

contract TestCreate4Factory is Test {
    bytes15 internal constant BOOTSTRAP_CODE = hex"3636363636335af13d36363e3d36f3";
    address internal constant EIP_1153_MAGIC = address(0x4549502d31313533);

    Create4Factory internal C4F;

    function expectedAddress(address deployer, bytes32 salt) internal view returns (address) {
        bytes32 bootstrapCodeHash = keccak256(abi.encodePacked(BOOTSTRAP_CODE, bytes20(address(deployer))));

        return
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(C4F), salt, bootstrapCodeHash)))));
    }

    function test_Success_create4_ExternalCode(
        address factoryAddress,
        address deployer,
        address deployedCodeAddress,
        bytes memory code,
        bytes32 salt
    ) public {
        if (code.length > 0) {
            // According to https://eips.ethereum.org/EIPS/eip-3541 contract creation (via create transaction, CREATE or CREATE2 instructions) results in an exceptional abort if the code’s first byte is 0xEF.
            vm.assume(code[0] != bytes1(0xef));
        }

        // Assume all actors have unique addresses
        vm.assume(factoryAddress != deployer);
        vm.assume(factoryAddress != deployedCodeAddress);
        vm.assume(deployer != deployedCodeAddress);

        // Assume nothing is set to the cheatcode address because somehow Forge found a fuzz seed that sets something to this and breaks it
        vm.assume(factoryAddress != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        vm.assume(deployer != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        vm.assume(deployedCodeAddress != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));

        // We're not allowed to etch to addresses lower than 10, so assume the factory and deployed code addresses we etch to are at least address(11)
        vm.assume(factoryAddress > address(10));
        vm.assume(deployedCodeAddress > address(10));

        // Ensure deployedCodeAddress isn't inadvertently set to the magic address, which would cause the contract to try to read the code from transient storage
        vm.assume(deployedCodeAddress != EIP_1153_MAGIC);

        vm.etch(factoryAddress, type(Create4Factory).runtimeCode);
        C4F = Create4Factory(payable(factoryAddress));

        vm.etch(deployedCodeAddress, code);

        vm.prank(deployer);

        address newContract = C4F.create4(deployedCodeAddress, salt);

        assertEq(
            newContract,
            expectedAddress(deployer, salt),
            "Create4Factory returned an address that does not match the deployer and provided salt"
        );
        assertEq(newContract.code, code, "The provided code was not present at the address of the new contract");
    }

    function test_Success_create4_DirectCode_Transient(
        address factoryAddress,
        address deployer,
        bytes memory code,
        bytes32 salt
    ) public {
        if (code.length > 0) {
            // According to https://eips.ethereum.org/EIPS/eip-3541 contract creation (via create transaction, CREATE or CREATE2 instructions) results in an exceptional abort if the code’s first byte is 0xEF.
            vm.assume(code[0] != bytes1(0xef));
        }

        // Assume nothing is set to the cheatcode address because somehow Forge found a fuzz seed that sets something to this and breaks it
        vm.assume(factoryAddress != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));
        vm.assume(deployer != address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));

        // We're not allowed to etch to addresses lower than 10, so assume the factory address we etch to is at least least address(11)
        vm.assume(factoryAddress > address(10));

        vm.etch(factoryAddress, type(Create4Factory).runtimeCode);
        C4F = Create4Factory(payable(factoryAddress));

        vm.prank(deployer);
        address newContract = C4F.create4(code, salt);

        assertEq(
            newContract,
            expectedAddress(deployer, salt),
            "Create4Factory returned an address that does not match the deployer and provided salt"
        );
        assertEq(newContract.code, code, "The provided code was not present at the address of the new contract");
    }

    /// forge-config: default.fuzz.runs = 100
    /// forge-config: ci.fuzz.runs = 10
    function test_Success_create4_Multiple(
        address factoryAddress,
        bool[1000] calldata ops,
        address[1000] calldata deployers,
        address[1000] calldata deployedCodeAddresses,
        bytes[1000] memory codes,
        bytes32[1000] calldata salts
    ) public {
        C4F = Create4Factory(payable(factoryAddress));
        for (uint256 i = 0; i < 1000; i++) {
            // You can't deploy a contract to an address that already has code, but if there was previously a deployment resulting in an empty code, you can deploy to that address again!
            if (expectedAddress(deployers[i], salts[i]).code.length > 0) continue;
            if (ops[i]) {
                test_Success_create4_ExternalCode(
                    factoryAddress, deployers[i], deployedCodeAddresses[i], codes[i], salts[i]
                );
            } else {
                test_Success_create4_DirectCode_Transient(factoryAddress, deployers[i], codes[i], salts[i]);
            }
        }
    }
}
