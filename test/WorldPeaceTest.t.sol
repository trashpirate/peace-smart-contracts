// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC721A} from "@erc721a/contracts/IERC721A.sol";

import {WorldPeace} from "src/WorldPeace.sol";
import {DeployWorldPeace} from "script/DeployWorldPeace.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract WorldPeaceTest is Test {
    /*//////////////////////////////////////////////////////////////
                             CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    DeployWorldPeace deployer;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig networkConfig;

    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/
    WorldPeace nftContract;
    ERC20Mock token;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    address USER = makeAddr("user");
    uint256 constant STARTING_BALANCE = 500_000_000 ether;
    address NEW_FEE_ADDRESS = makeAddr("fee");
    uint256 constant NEW_FEE = 0.001 ether;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event EthFeeSet(address indexed sender, uint256 indexed fee);
    event TokenFeeSet(address indexed sender, uint256 indexed fee);
    event FeeAddressSet(address indexed sender, address indexed feeAddress);

    /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    modifier funded(address account) {
        // fund user with eth
        deal(account, 1000 ether);

        // fund user with tokens
        token.mint(account, STARTING_BALANCE);

        _;
    }
    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() external virtual {
        deployer = new DeployWorldPeace();
        (nftContract, helperConfig) = deployer.run();

        networkConfig = helperConfig.getActiveNetworkConfigStruct();

        token = ERC20Mock(nftContract.getFeeToken());
    }

    function fund(address account) public {
        // fund user with eth
        deal(account, 10000 ether);

        // fund user with tokens
        token.mint(account, STARTING_BALANCE);
    }

    function test__test() public {
        console.log("This is a test");
    }

    /*//////////////////////////////////////////////////////////////
                          TEST   INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function test__NFTFeeHandler__Initialization() public {
        assertEq(nftContract.getFeeAddress(), networkConfig.args.feeAddress);
        assertEq(nftContract.getFeeToken(), networkConfig.args.tokenAddress);

        assertEq(nftContract.getEthFee(), networkConfig.args.ethFee);
        assertEq(nftContract.getTokenFee(), networkConfig.args.tokenFee);

        assertEq(nftContract.getMaxWalletSize(), networkConfig.args.coreConfig.maxWalletSize);
        assertEq(nftContract.getBatchLimit(), networkConfig.args.coreConfig.batchLimit);

        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        nftContract.tokenURI(1);
    }
}
