// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV2Pair} from "../src/core/UniswapV2Pair.sol";

contract GetInitCodeHash is Script {
    function run() external view returns (bytes32) {
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 hash = keccak256(bytecode);
        console.log("Init code hash:");
        console.logBytes32(hash);
        return hash;
    }
}

