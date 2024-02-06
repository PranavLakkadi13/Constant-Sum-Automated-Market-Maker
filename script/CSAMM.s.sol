// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {CSAMM} from "../src/CSAMM.sol";
import { IERC20 } from "../src/IERC20.sol";
import { MockBTC } from "../src/MockERC20.sol";

contract CSAMMScript is Script {

    MockBTC public btc;
    MockBTC public eth;
    CSAMM public protocol;

    function run() public {
        vm.startBroadcast();
        btc = new MockBTC("BITCOIN","BTC");
        eth = new MockBTC("ETHEREUM","ETH");
        protocol = new CSAMM(address(btc),address(eth));
        vm.stopBroadcast();
    }
}
