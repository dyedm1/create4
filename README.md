# CREATE4

[![tests](https://github.com/dyedm1/create4/actions/workflows/ci.yml/badge.svg)](https://github.com/dyedm1/create4/actions/workflows/ci.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Brief history lesson
[EIP-3171](https://github.com/ethereum/EIPs/pull/3171) was an EIP that introduced a new native opcode (`CREATE3`) that enabled deterministic contract creation similar to that of `CREATE2` but with the `initcode` removed from the address derivation formula. Unfortunately, the EIP was rejected, in part due to the emergence of [a popular application-layer approximation bearing the same name.](https://github.com/0xsequence/create3) However, this approximation leveraged a combination of the `CREATE` and `CREATE2` opcodes to achieve its functionality, and in doing so increased the compute cost of mining efficient addresses by severalfold while also breaking compatibility with [existing salt mining tooling.](https://github.com/0age/create2crunch)  

## Summary
`CREATE4` is a different approach to approximating the functionality lost in the rejection of EIP-3171. Despite the name, the address derivation formula for `CREATE4` is significantly closer to what a native `CREATE3` opcode would have possessed than the original [`CREATE3` app-layer implementation](https://github.com/0xsequence/create3) was. Because `CREATE4` uses a single `CREATE2` call with a fixed `initCode` under the hood, [create2crunch](https://github.com/0age/create2crunch) can be used to mine `CREATE4` salts for efficient addresses at no additional compute cost over `CREATE2` mining.

## Create4Factory (`CREATE4` Implementation)

### How
1. Store the `deployedCode` of the desired contract somewhere on-chain 
   (in order of gas cost)
   - If the network supports [EIP-1153](https://eips.ethereum.org/EIPS/eip-1153) store the code in transient storage with `TSTORE`
   - If the network does not support [EIP-1153](https://eips.ethereum.org/EIPS/eip-1153) deploy the contract using your method of choice and use the address as a reference to the code
2. Expose the `deployedCode` via a getter function with support for returning from both transient storage and from a contract address based on previously set flags in storage. This ensures that the method of code storage does not affect the address derivation formula.
3. `CREATE2` with a user's salt and "bootstrap" `initCode` containing their address somewhere (for front-running protection) that queries the `deployedCode` from the getter function and returns it.
4. We now have a process that can be used to deploy any bytecode with a deterministic address based on the `msg.sender` and a salt.

### Initcode for address derivation

For `Create4Factory`, the `initCode` is constructed as follows:
- Code segment 1: `5f5f5f5f5f73` 
- `Create4Factory` address: `ffffffffffffffffffffffffffffffffffffffff`
- Code segment 2: `5af13d5f5f3e3d5ff3`
- Deployer address (user calling `create4`): `ffffffffffffffffffffffffffffffffffffffff`

Result: `0x5f5f5f5f5f73<Create4Factory address>5af13d5f5f3e3d5ff3<deployer address>`
#### Example
If we have
- `Create4Factory` address: `0xe358511cd9bf45c8a4d4aaf96ad5f6234ad20282` (note: not the real-world address!)
- Deployer address: `0xab5801a7d398351b8be11c439e05c5b3259aec9b` (Vb)

Our `initCode` would be:
`0x5f5f5f5f5f73e358511cd9bf45c8a4d4aaf96ad5f6234ad202825af13d5f5f3e3d5ff3ab5801a7d398351b8be11c439e05c5b3259aec9b`

### Features

- Deterministic contract address based on `msg.sender` + salt
- Simple, `CREATE2`-compatible address derivation formula with ideal compute cost
- Front-running protection
- Cheaper than [CREATE3](https://github.com/0xsequence/create3) for smaller contracts on chains with EIP-1153 support
- Same contract addresses on different EVM networks (even those without support for EIP-1153)
- Supports any EVM compatible chain with support for CREATE2 (& PUSH0)

### Limitations

- ~2x deployment cost increase for chains without EIP-1153 (transient storage) support
- ~5% deployment cost increase for chains with EIP-1153 support
- No constructor support (deployed bytecode must be precomputed)

### Cross-chain Deployments

None yet :)

### Usage

Call the `create4` method on the `Create4Factory`, provide the contract `creationCode` (on EIP-1153 networks) or the address of a deployed contract containing the code you want to deploy (on non-EIP-1153 networks) and a salt. Different contract codes will result on the same address as long as the same salt is provided.

### Install (interface)    
```bash
forge install dyedm1/create4
```

## Commands

### Build
```bash
forge build --use bin/solc
```

### Run tests
```bash
forge test --use bin/solc
```

### Format
```bash
forge fmt
```

## Contract example

```javascript
//SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import {Create4} from "lib/create4/src/Create4Factory.sol";


contract CreateMe {
  function test() external view returns (uint256) {
    return 0x1337;
  }
}

contract Deployer {
  function deployChild() external {
    Create4Factory(0x0000000000000000000000000000000000000000).create4(type(CreateMe).deploymentCode, bytes32(0x1337));
  }
}
```


# License 
Code in this repository is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) unless otherwise indicated (see [LICENSE](./LICENSE) file).
