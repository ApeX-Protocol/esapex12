// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDTMock is ERC20 {
    constructor() ERC20("USDTMock", "USDTMock") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

contract APEXMock is ERC20 {
    constructor() ERC20("APEXMock", "APEXMock") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}

contract DeployERC20 is Script {
    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        (, , uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);

        // Deploy the logic contract
        APEXMock apexToken = new APEXMock();
        USDTMock usdtToken = new USDTMock();

        console.log("APEXMock Address: ", address(apexToken));
        console.log("USDTMock Address: ", address(usdtToken));

        vm.stopBroadcast();
    }
}
