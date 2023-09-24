// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

contract Create4Factory {
    // hex("EIP-1153")
    // We set currentDeployment to this address to signal that the code can be read from transient storage
    address internal constant EIP_1153_MAGIC = address(0x4549502d31313533);

    /*
        [26 BYTES]
        PUSH0 // retSize: 0
        PUSH0 // retOffset: 0
        PUSH0 // argsSize: 0
        PUSH0 // argsOffset: 0
        PUSH0 // value: 0
        PUSH20 (0x0000000000000000000000000000000000000000) // FACTORY ADDRESS(THIS), FILLED DYNAMICALLY 
        Right-padded with 0s to 32 bytes
    */
    bytes32 internal constant BOOTSTRAP_CODE_SECTION_1 =
        hex"5f5f5f5f5f73000000000000000000000000000000000000000000000000";

    /*
        [29 BYTES]
        GAS // gas (gas remaining in frame)
        CALL
        RETURNDATASIZE // size (of returned code to copy)
        PUSH0 // offset: 0
        PUSH0 // destOffset: 0
        RETURNDATACOPY
        RETURNDATASIZE // size (of code to return/deploy)
        PUSH0 // offset: 0
        RETURN
        (0x0000000000000000000000000000000000000000) // MSG.SENDER, FILLED DYNAMICALLY
        Right-padded with 0s to 32 bytes
    */
    bytes32 internal constant BOOTSTRAP_CODE_SECTION_2 =
        hex"5af13d5f5f3e3d5ff30000000000000000000000000000000000000000000000";

    address internal currentDeployment;

    uint96 internal currentSize;

    function create4(address deployedCode, bytes32 salt) public returns (address newContract) {
        currentDeployment = deployedCode;

        assembly {
            mstore(0, BOOTSTRAP_CODE_SECTION_1)
            mstore(6, shl(96, address()))
            mstore(26, BOOTSTRAP_CODE_SECTION_2)
            mstore(35, shl(96, caller()))
            newContract := create2(0, 0, 55, salt)
        }
    }

    function create4(bytes memory deployedCode, bytes32 salt) public returns (address newContract) {
        currentDeployment = EIP_1153_MAGIC;
        uint96 size = uint96(deployedCode.length);
        currentSize = size;

        assembly {
            for { let i := 0 } lt(mul(i, 32), size) { i := add(i, 1) } {
                tstore(i, mload(add(deployedCode, add(32, mul(i, 32)))))
            }
            mstore(0, BOOTSTRAP_CODE_SECTION_1)
            mstore(6, shl(96, address()))
            mstore(26, BOOTSTRAP_CODE_SECTION_2)
            mstore(35, shl(96, caller()))
            newContract := create2(0, 0, 55, salt)
        }
    }

    receive() external payable {
        address _currentDeployment = currentDeployment;
        if (_currentDeployment == EIP_1153_MAGIC) {
            uint96 size = currentSize;
            assembly {
                for { let i := 0 } lt(mul(i, 32), size) { i := add(i, 1) } { mstore(mul(i, 32), tload(i)) }
                return(0, size)
            }
        } else {
            // use assembly to bypass ABI encoding and make output easier to process from bootstrap code
            assembly {
                let size := extcodesize(_currentDeployment)
                extcodecopy(_currentDeployment, 0, 0, size)
                return(0, size)
            }
        }
    }
}
