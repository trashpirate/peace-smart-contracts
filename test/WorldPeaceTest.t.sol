// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC721A, IERC721A} from "@erc721a/contracts/ERC721A.sol";

import {WorldPeace, ERC721ACore, Pausable, FeeHandler, Whitelist} from "src/WorldPeace.sol";
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
    uint256 constant NEW_BATCH_LIMIT = 20;
    uint256 constant NEW_MAX_WALLET_SIZE = 20;
    uint256 constant STARTING_BALANCE = 500_000_000 ether;
    address NEW_FEE_ADDRESS = makeAddr("fee");
    uint256 constant NEW_FEE = 0.001 ether;

    address VALID_USER;
    uint256 VALID_USER_KEY;

    bytes32 MERKLE_ROOT = 0x7cfda1d6c2b32e261fbdf50526b103173ab06cb1879095dddc3d2c5feb96198a;
    bytes32 NEW_MERKLE_ROOT = 0xbac43dadde51c6caaf0ac2afedd5b01a2309d7949eb885502006523739248f9c;

    bytes32[] VALID_PROOF = [
        bytes32(0xfd28eb2cd1dab1d4e95dafc7b249eff8e75eabe37548efb05dada899264f25b4),
        0x603ab331089101552b9dde23779eab62af9b50242bdd77dd16f4dd86fe748129,
        0xf67ea6e5dd288a14836f06064b781d7e30ca3af8ea340931d7bde127af0a0757,
        0x77f4ff80b42f3ed7f596900be1a0e7a2abf1e01b26372fe2af0957c15c93d0ac,
        0x563314bbe031d9c0bcb7e68735ffe7d64b03eb46186064d3cbcab90aee1621f7
    ];

    bytes32[] INVALID_PROOF = [
        bytes32(0xfd28eb2cd1dab1d4e95dafc7b249eff8e75eabe37548efb05dada899264f25b4),
        0x603ab331089101552b9dde23779eab62af9b50242bdd77dd16f4dd86fe748125,
        0xf67ea6e5dd288a14836f06064b781d7e30ca3af8ea340931d7bde127af0a0757,
        0x77f4ff80b42f3ed7f596900be1a0e7a2abf1e01b26372fe2af0957c15c93d0ac,
        0x563314bbe031d9c0bcb7e68735ffe7d64b03eb46186064d3cbcab90aee1621f7
    ];

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event BatchLimitSet(address indexed sender, uint256 batchLimit);
    event MaxWalletSizeSet(address indexed sender, uint256 maxWalletSize);
    event BaseURIUpdated(address indexed sender, string indexed baseUri);
    event ContractURIUpdated(address indexed sender, string indexed contractUri);
    event RoyaltyUpdated(address indexed feeAddress, uint96 indexed royaltyNumerator);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event EthFeeSet(address indexed sender, uint256 indexed fee);
    event TokenFeeSet(address indexed sender, uint256 indexed fee);
    event FeeAddressSet(address indexed sender, address indexed feeAddress);
    event Paused(address indexed sender);
    event Unpaused(address indexed sender);
    event MerkleRootSet(address indexed account, bytes32 indexed merkleRoot);

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

    modifier unpaused() {
        vm.startPrank(nftContract.owner());
        nftContract.unpause();
        vm.stopPrank();
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

        (VALID_USER, VALID_USER_KEY) = makeAddrAndKey("user");
    }

    function fund(address account) public {
        // fund user with eth
        deal(account, 10000 ether);

        // fund user with tokens
        token.mint(account, STARTING_BALANCE);
    }

    function approveTokens(address account, uint256 quantity) public {
        uint256 tokenFee = quantity * nftContract.getTokenFee();

        vm.prank(account);
        token.approve(address(nftContract), tokenFee);
    }

    /*//////////////////////////////////////////////////////////////
                          TEST   INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__Initialization() public {
        assertEq(nftContract.getFeeAddress(), networkConfig.args.feeAddress);
        assertEq(nftContract.getFeeToken(), networkConfig.args.tokenAddress);

        assertEq(nftContract.getEthFee(), networkConfig.args.ethFee);
        assertEq(nftContract.getTokenFee(), networkConfig.args.tokenFee);

        assertEq(nftContract.getMaxWalletSize(), networkConfig.args.coreConfig.maxWalletSize);
        assertEq(nftContract.getBatchLimit(), networkConfig.args.coreConfig.batchLimit);

        assertEq(nftContract.isPaused(), true);

        assertEq(nftContract.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(nftContract.supportsInterface(0x2a55205a), true); // ERC2981

        vm.expectRevert(abi.encodeWithSelector(WorldPeace.WorldPeace__URIQueryForNonexistentToken.selector, 1));
        nftContract.tokenURI(1);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST DEPLOYMENT
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__RevertWhen__NoBaseURI() public {
        HelperConfig.ConstructorArguments memory args = networkConfig.args;

        args.coreConfig.baseURI = "";

        vm.expectRevert(ERC721ACore.ERC721ACore_NoBaseURI.selector);
        new WorldPeace(args.coreConfig, args.feeAddress, args.tokenAddress, args.tokenFee, args.ethFee, args.merkleRoot);
    }

    /*//////////////////////////////////////////////////////////////
                               TEST MINT
    //////////////////////////////////////////////////////////////*/

    /// SUCCESS
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__Mint(uint256 quantity, address account) public skipFork unpaused {
        quantity = bound(quantity, 1, nftContract.getBatchLimit());
        vm.assume(account != address(0));
        vm.assume(account != nftContract.getFeeAddress());
        vm.assume(account.code.length == 0);

        fund(account);

        uint256 feeTokenBalance = token.balanceOf(nftContract.getFeeAddress());
        uint256 tokenBalance = token.balanceOf(account);

        uint256 tokenFee = quantity * nftContract.getTokenFee();

        approveTokens(account, quantity);
        vm.prank(account);
        nftContract.mint(quantity, INVALID_PROOF);

        assertEq(nftContract.balanceOf(account), quantity);
        assertEq(token.balanceOf(account), tokenBalance - tokenFee);
        assertEq(token.balanceOf(nftContract.getFeeAddress()), feeTokenBalance + tokenFee);
    }

    function test__WorldPeace__MintWhitelist(uint256 quantity) public skipFork unpaused funded(VALID_USER) {
        quantity = bound(quantity, 1, nftContract.getBatchLimit());

        uint256 feeTokenBalance = token.balanceOf(nftContract.getFeeAddress());
        uint256 tokenBalance = token.balanceOf(VALID_USER);

        uint256 tokenFee = (quantity - 1) * nftContract.getTokenFee();

        approveTokens(VALID_USER, quantity - 1);
        vm.prank(VALID_USER);
        nftContract.mint(quantity, VALID_PROOF);

        assertEq(nftContract.hasClaimed(VALID_USER), true);
        assertEq(nftContract.balanceOf(VALID_USER), quantity);
        assertEq(token.balanceOf(VALID_USER), tokenBalance - tokenFee);
        assertEq(token.balanceOf(nftContract.getFeeAddress()), feeTokenBalance + tokenFee);
    }

    /// EVENT EMITTED
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__EmitEvent__Mint() public unpaused funded(USER) {
        approveTokens(USER, 1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), USER, 1);
        vm.prank(USER);
        nftContract.mint(1, INVALID_PROOF);
    }

    /// REVERTS
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__RevertWhen__InsufficientMintQuantity() public unpaused funded(USER) {
        approveTokens(USER, 1);

        vm.expectRevert(IERC721A.MintZeroQuantity.selector);
        vm.prank(USER);
        nftContract.mint(0, INVALID_PROOF);
    }

    function test__WorldPeace__RevertWhen__MintExceedsBatchLimit() public unpaused funded(USER) {
        uint256 quantity = nftContract.getBatchLimit() + 1;
        approveTokens(USER, quantity);

        vm.expectRevert(ERC721ACore.ERC721ACore_ExceedsBatchLimit.selector);

        vm.prank(USER);
        nftContract.mint(quantity, INVALID_PROOF);
    }

    function test__WorldPeace__RevertWhen__MintExceedsMaxWalletSize() public unpaused funded(USER) {
        uint256 quantity = nftContract.getMaxWalletSize() + 1;

        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.setBatchLimit(quantity);

        approveTokens(USER, quantity);
        vm.expectRevert(ERC721ACore.ERC721ACore_ExceedsMaxPerWallet.selector);

        vm.prank(USER);
        nftContract.mint(quantity, INVALID_PROOF);
    }

    function test__WorldPeace__RevertWhen__MaxSupplyExceeded() public unpaused funded(USER) {
        uint256 maxSupply = nftContract.getMaxSupply();

        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.setMaxWalletSize(maxSupply);

        for (uint256 index = 0; index < maxSupply; index++) {
            approveTokens(USER, 1);
            vm.prank(USER);
            nftContract.mint(1, INVALID_PROOF);
        }

        approveTokens(USER, 1);
        vm.expectRevert(ERC721ACore.ERC721ACore_ExceedsMaxSupply.selector);
        vm.prank(USER);
        nftContract.mint(1, INVALID_PROOF);
    }

    function test__WorldPeace__RevertsWhen__MintWhitelistHasClaimed() public unpaused funded(VALID_USER) {
        approveTokens(VALID_USER, 2);
        vm.prank(VALID_USER);
        nftContract.mint(1, VALID_PROOF);

        vm.expectRevert(Whitelist.Whitelist__AlreadyClaimed.selector);
        vm.prank(VALID_USER);
        nftContract.mint(1, VALID_PROOF);
    }

    /*//////////////////////////////////////////////////////////////
                             TEST TOKENURI
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__RetrieveTokenUri() public unpaused funded(USER) {
        approveTokens(USER, 1);
        vm.prank(USER);
        nftContract.mint(1, INVALID_PROOF);

        assertEq(nftContract.tokenURI(1), networkConfig.args.coreConfig.baseURI);
    }

    function test__WorldPeace__UniversalTokenURI() public unpaused funded(USER) {
        uint256 maxSupply = nftContract.getMaxSupply();
        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.setMaxWalletSize(maxSupply);

        for (uint256 index = 1; index <= maxSupply; index++) {
            approveTokens(USER, 1);
            vm.prank(USER);
            nftContract.mint(1, INVALID_PROOF);
            assertEq(nftContract.tokenURI(index), nftContract.getBaseURI());
        }
    }

    /*//////////////////////////////////////////////////////////////
                               TEST PAUSE
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__UnPause() public {
        address owner = nftContract.owner();

        vm.prank(owner);
        nftContract.unpause();

        assertEq(nftContract.isPaused(), false);
    }

    function test__WorldPeace__Pause() public {
        address owner = nftContract.owner();

        vm.prank(owner);
        nftContract.unpause();

        vm.prank(owner);
        nftContract.pause();

        assertEq(nftContract.isPaused(), true);
    }

    function test__WorldPeace__EmitEvent__Pause() public {
        address owner = nftContract.owner();

        vm.expectEmit(true, true, true, true);
        emit Unpaused(owner);

        vm.prank(owner);
        nftContract.unpause();
    }

    function test__WorldPeace__EmitEvent__Unpause() public {
        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.unpause();

        vm.expectEmit(true, true, true, true);
        emit Paused(owner);

        vm.prank(owner);
        nftContract.pause();
    }

    function test__WorldPeace__RevertsWhen__NotOwnerPauses() public {
        address owner = nftContract.owner();

        vm.prank(owner);
        nftContract.unpause();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        vm.prank(USER);
        nftContract.pause();
    }

    function test__WorldPeace__RevertsWhen__PauseAlreadyPaused() public {
        address owner = nftContract.owner();

        vm.expectRevert(Pausable.Pausable_ContractIsPaused.selector);

        vm.prank(owner);
        nftContract.pause();
    }

    function test__WorldPeace__RevertsWhen__UnpauseAlreadyUnpaused() public {
        address owner = nftContract.owner();

        vm.prank(owner);
        nftContract.unpause();

        vm.expectRevert(Pausable.Pausable_ContractIsUnpaused.selector);

        vm.prank(owner);
        nftContract.unpause();
    }

    /*//////////////////////////////////////////////////////////////
                           TEST SET FEEADDRESS
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__SetEthFeeAddress() public {
        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.setFeeAddress(NEW_FEE_ADDRESS);
        assertEq(nftContract.getFeeAddress(), NEW_FEE_ADDRESS);
    }

    function test__WorldPeace__EmitEvent__SetEthFeeAddress() public {
        address owner = nftContract.owner();

        vm.expectEmit(true, true, true, true);
        emit FeeAddressSet(owner, NEW_FEE_ADDRESS);

        vm.prank(owner);
        nftContract.setFeeAddress(NEW_FEE_ADDRESS);
    }

    function test__WorldPeace__RevertWhen__FeeAddressIsZero() public {
        address owner = nftContract.owner();
        vm.prank(owner);

        vm.expectRevert(FeeHandler.FeeHandler_FeeAddressIsZeroAddress.selector);
        nftContract.setFeeAddress(address(0));
    }

    function test__WorldPeace__RevertWhen__NotOwnerSetsFeeAddress() public {
        vm.prank(USER);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        nftContract.setFeeAddress(NEW_FEE_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST SET TOKENFEE
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__SetTokenFee() public {
        address owner = nftContract.owner();
        vm.prank(owner);
        nftContract.setTokenFee(NEW_FEE);
        assertEq(nftContract.getTokenFee(), NEW_FEE);
    }

    function test__WorldPeace__EmitEvent__SetTokenFee() public {
        address owner = nftContract.owner();

        vm.expectEmit(true, true, true, true);
        emit TokenFeeSet(owner, NEW_FEE);

        vm.prank(owner);
        nftContract.setTokenFee(NEW_FEE);
    }

    function test__WorldPeace__RevertWhen__NotOwnerSetsTokenFee() public {
        vm.prank(USER);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        nftContract.setTokenFee(NEW_FEE);
    }

    /*//////////////////////////////////////////////////////////////
                            SET MERKLE ROOT
    //////////////////////////////////////////////////////////////*/
    function test__WorldPeace__SetMerkleRoot() external {
        address owner = nftContract.owner();

        vm.prank(owner);
        nftContract.setMerkleRoot(NEW_MERKLE_ROOT);

        assertEq(nftContract.getMerkleRoot(), NEW_MERKLE_ROOT);
    }

    function test__ERC721AWhitelist__EmitEvent__SetMerkleRoot() public {
        address owner = nftContract.owner();

        vm.expectEmit(true, true, true, true);
        emit MerkleRootSet(owner, NEW_MERKLE_ROOT);

        vm.prank(owner);
        nftContract.setMerkleRoot(NEW_MERKLE_ROOT);
    }

    function test__WorldPeace__RevertWhen__NotOwnerSetsMerkleRoot() public {
        vm.prank(USER);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, USER));
        nftContract.setMerkleRoot(NEW_MERKLE_ROOT);
    }
}
