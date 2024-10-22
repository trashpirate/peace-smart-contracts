// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {WorldPeace} from "src/WorldPeace.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployWorldPeace is Script {
    HelperConfig public helperConfig;

    function run() external returns (WorldPeace, HelperConfig) {
        helperConfig = new HelperConfig();
        HelperConfig.ConstructorArguments memory args = helperConfig.activeNetworkConfig();

        // after broadcast is real transaction, before just simulation
        vm.startBroadcast();
        uint256 gasLeft = gasleft();
        WorldPeace nfts = new WorldPeace(
            args.coreConfig, args.feeAddress, args.tokenAddress, args.tokenFee, args.ethFee, args.merkleRoot
        );
        console.log("Deployment gas: ", gasLeft - gasleft());
        vm.stopBroadcast();
        return (nfts, helperConfig);
    }
}
