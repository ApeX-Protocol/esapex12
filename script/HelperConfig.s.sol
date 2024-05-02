// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address usdtToken;
        address apexToken;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 5000) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 5003) {
            activeNetworkConfig = getSepoliaMantleConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getMainnetEthConfig()
        public
        view
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            usdtToken: 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE,
            apexToken: 0x96630b0D78d29E7E8d87f8703dE7c14b2d5AE413,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaMantleConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            usdtToken: 0xC089580aCEcC435F62c81Db00DCC1B6FBc752394, // todo deploy and change
            apexToken: 0xC089580aCEcC435F62c81Db00DCC1B6FBc752394, // todo deploy and change
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            usdtToken: 0x076557d73F06E2Cb2654019F6707f524a213Cf1c, // todo deploy and change
            apexToken: 0x1ba786ACd9f97A5F64CB0593C6E7B41FB8CAd270, // todo deploy and change
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        vm.startBroadcast();
        ERC20Mock usdtToken = new ERC20Mock();
        ERC20Mock apexToken = new ERC20Mock();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            usdtToken: address(usdtToken),
            apexToken: address(apexToken),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
