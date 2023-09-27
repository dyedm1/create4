// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title CREATE4 — easy-to-mine contract addresses with deterministic initcode
 * @notice Full support for networks with EIP-1153 & EIP-3855 support
 * @notice Partial support for networks with only EIP-3855 support — create4(address, salt) is functional, but create4(bytes, salt) is not
 * @notice Does not support networks without EIP-3855 support
 * @author dyedM1
 */
contract Create4Factory {
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
        (0x0000000000000000000000000000000000000000) // MSG.SENDER, FILLED DYNAMICALLY (appended for frontrunning protection)
        Right-padded with 0s to 32 bytes
    */
    bytes32 internal constant BOOTSTRAP_CODE_SECTION_2 =
        hex"5af13d5f5f3e3d5ff30000000000000000000000000000000000000000000000";

    uint256 internal constant UINT256_MAX = 2 ** 256 - 1;

    // hex("EIP-1153")
    // We set currentDeployment to this address to signal that the code can be read from transient storage
    address internal constant EIP_1153_MAGIC = address(0x4549502d31313533);

    // Set in create4(address, bytes32) to store the address containing the code to return from `receive()` when called by the bootstrap code
    // Set to EIP_1153_MAGIC in create4(bytes, bytes32) to signal that the code can be read from transient storage instead in `receive()`
    address internal currentDeployment;

    /// @notice Deploys the code present at `deployedCode` with CREATE2 using `salt`
    /// @dev Can function on networks without EIP-1153 support
    /// @dev Cheaper to call, but most likely more expensive overall due to the cost of creating `deployedCode`
    /// @dev Use this method only if:
    /// - You are deploying code that is already present onchain (and thus carries no additional deployment cost)
    /// AND/OR
    /// - You want to deploy code to multiple chains, but some or all do not support EIP-1153
    /// (the functions can be used interchangeably across chains resulting in the same address, so only use this on the networks without EIP-1153 support)
    /// OR
    /// - You are only deploying to non-EIP-1153 networks and do not know the code in advance, but have determined the additional deployment cost is worth the compute savings in salt mining
    /// @param deployedCode Contract address containing the code to deploy
    /// @param salt 256-bit salt to use with CREATE2 that determines the final address along with msg.sender
    /// @return newContract Address of the newly deployed contract
    function create4(address deployedCode, bytes32 salt) public payable returns (address newContract) {
        currentDeployment = deployedCode;

        assembly {
            mstore(0, BOOTSTRAP_CODE_SECTION_1)
            mstore(6, shl(96, address()))
            mstore(26, BOOTSTRAP_CODE_SECTION_2)
            mstore(35, shl(96, caller()))

            newContract := create2(0, 0, 55, salt)
        }
    }

    /// @notice Deploys `deployedCode` with CREATE2 using `salt`
    /// @dev Can only function on networks with EIP-1153 support
    /// @dev More expensive to call, but most likely cheaper overall since the cost of creating `deployedCode` is avoided
    /// @dev Use this method only if:
    /// - You are deploying code that is not already present onchain (and thus carries an additional deployment cost for create4(address, bytes32))
    /// AND
    /// - You are deploying to a network with EIP-1153 support
    /// @param deployedCode Code to deploy
    /// @param salt 256-bit salt to use with CREATE2 that determines the final address along with msg.sender
    /// @return newContract Address of the newly deployed contract
    function create4(bytes memory deployedCode, bytes32 salt) public payable returns (address newContract) {
        // Set currentDeployment to EIP_1153_MAGIC to signal that the code can be read from transient storage
        currentDeployment = EIP_1153_MAGIC;

        assembly {
            let size := mload(deployedCode)

            // the size could be packed with currentDeployment in storage, but this is a little simpler
            // Store at UINT256_MAX to avoid collisions with the stored bytecode
            tstore(UINT256_MAX, size)

            // store deployedCode in transient storage with 32 byte chunks from index 0 to ceiling(size / 32)
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

    /// @notice Called by the bootstrap code to retrieve the desired code to deploy
    /// @dev IF `currentDeployment` is set to EIP_1153_MAGIC, the code (and size) is read from transient storage
    /// @dev Otherwise, the code (and size) is read from the address stored in `currentDeployment`
    receive() external payable {
        address _currentDeployment = currentDeployment;
        if (_currentDeployment == EIP_1153_MAGIC) {
            assembly {
                let size := tload(UINT256_MAX)

                // load deployedCode from transient storage into memory, index 0 to ceiling(size / 32)
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
