// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ESAPEX12} from "../src/ESAPEX12.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {
    ProxyAdmin,
    TransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployESAPEX12 is Script {
    function run() public returns (TransparentUpgradeableProxy, address, address, address) {
        HelperConfig helperConfig = new HelperConfig();
        (address usdtToken, address apexToken, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        address owner = vm.addr(deployerKey);
        console.log("owner = ", owner);

        // Deploy the logic contract
        ESAPEX12 esAPEX12Logic = new ESAPEX12();

        // Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin(owner);

        // Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            ESAPEX12.initialize.selector, owner, address(usdtToken), address(apexToken), "esAPEX12", "esAPEX12"
        );

        // Deploy the Transparent Upgradeable Proxy
        TransparentUpgradeableProxy transparentProxy =
            new TransparentUpgradeableProxy(address(esAPEX12Logic), address(proxyAdmin), initData);

        console.log("esApex12 Logic Address:", address(esAPEX12Logic));
        console.log("ProxyAdmin Address:", address(proxyAdmin));
        console.log("Transparent Proxy Address:", address(transparentProxy));

        vm.stopBroadcast();

        return (transparentProxy, usdtToken, apexToken, owner);
    }
}
