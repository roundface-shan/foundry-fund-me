// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetWorkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetWorkConfig {
        address priceFeed;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetWorkConfig memory) {
        NetWorkConfig memory sepoliaConfig = NetWorkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getAnvilEthConfig() public returns (NetWorkConfig memory) {
        vm.startBroadcast();
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

        NetWorkConfig memory anvilConfig = NetWorkConfig({
            priceFeed: address(mockV3Aggregator)
        });
        return anvilConfig;
    }
}
