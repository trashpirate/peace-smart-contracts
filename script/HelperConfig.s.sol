// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC721ACore} from "nft-contracts/ERC721ACore.sol";

contract HelperConfig is Script {
    struct ConstructorArguments {
        ERC721ACore.CoreConfig coreConfig;
        address feeAddress;
        address tokenAddress;
        uint256 tokenFee;
        uint256 ethFee;
        bytes32 merkleRoot;
    }

    struct NetworkConfig {
        ConstructorArguments args;
    }

    // nft configurations
    string public NAME = "World Peace";
    string public SYMBOL = "PEACE";
    string public BASE_URI = "ipfs://bafybeidunoa4h3e5kvddib6gi53nhmbm32lzvcaxqccdforsiih2mwubky/";
    string public CONTRACT_URI = "ipfs://bafkreiez4tklbxcv5e45s5zed5l2x2atmf7d26lfuo42xbbddnlppnzngm";
    uint256 public MAX_SUPPLY = 20000;
    uint256 public ETH_FEE = 0.000777 ether;
    uint256 public TOKEN_FEE = 0;

    bytes32 public MERKLE_ROOT = 0x7cfda1d6c2b32e261fbdf50526b103173ab06cb1879095dddc3d2c5feb96198a;

    // chain configurations
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 1 || block.chainid == 8453 || block.chainid == 123) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 84532 || block.chainid == 11155111) {
            activeNetworkConfig = getTestnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getActiveNetworkConfigStruct() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            args: ConstructorArguments({
                coreConfig: ERC721ACore.CoreConfig({
                    name: NAME,
                    symbol: SYMBOL,
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    owner: vm.envAddress("OWNER_ADDRESS"),
                    maxSupply: MAX_SUPPLY,
                    maxWalletSize: 10,
                    batchLimit: 10,
                    royaltyNumerator: 500 // 5%
                }),
                feeAddress: vm.envAddress("FEE_ADDRESS"),
                tokenAddress: vm.envAddress("TOKEN_ADDRESS"),
                ethFee: ETH_FEE,
                tokenFee: TOKEN_FEE,
                merkleRoot: MERKLE_ROOT
            })
        });
    }

    function getTestnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            args: ConstructorArguments({
                coreConfig: ERC721ACore.CoreConfig({
                    name: NAME,
                    symbol: SYMBOL,
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    owner: vm.envAddress("OWNER_ADDRESS"),
                    maxSupply: MAX_SUPPLY,
                    maxWalletSize: 10,
                    batchLimit: 10,
                    royaltyNumerator: 500 // 5%
                }),
                feeAddress: vm.envAddress("FEE_ADDRESS"),
                tokenAddress: vm.envAddress("TOKEN_ADDRESS"),
                ethFee: ETH_FEE,
                tokenFee: TOKEN_FEE,
                merkleRoot: MERKLE_ROOT
            })
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        // Deploy mock contracts
        vm.startBroadcast();
        ERC20Mock token = new ERC20Mock();
        vm.stopBroadcast();

        return NetworkConfig({
            args: ConstructorArguments({
                coreConfig: ERC721ACore.CoreConfig({
                    name: NAME,
                    symbol: SYMBOL,
                    baseURI: BASE_URI,
                    contractURI: CONTRACT_URI,
                    owner: vm.envAddress("ANVIL_DEFAULT_ACCOUNT"),
                    maxSupply: MAX_SUPPLY,
                    maxWalletSize: 10,
                    batchLimit: 10,
                    royaltyNumerator: 500 // 5%
                }),
                feeAddress: vm.envAddress("ANVIL_DEFAULT_ACCOUNT"),
                tokenAddress: address(token),
                ethFee: ETH_FEE,
                tokenFee: TOKEN_FEE,
                merkleRoot: MERKLE_ROOT
            })
        });
    }
}
