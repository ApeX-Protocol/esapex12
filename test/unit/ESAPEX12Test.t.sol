// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DeployESAPEX12} from "../../script/DeployESAPEX12.s.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Test, console2} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ESAPEX12} from "../../src/ESAPEX12.sol";
import {LPToken} from "../../src/libraries/LPToken.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ESAPEX12Test is StdCheats, Test {
    event InitalStakerUpdated(address user, bool isAllowed);
    event InitalStakerApexStaked(address indexed user, uint256 amount);
    event PriceUpdated(uint256 indexed newPrice, address indexed updater);
    event Paused(address account);
    event TimelockCreated(
        uint256 indexed timelockId,
        address indexed user,
        uint256 amount,
        uint256 timelockStart
    );
    event TimelockRedeemed(uint256 indexed timelockId, address indexed user);
    event TimelockCancelled(uint256 indexed timelockId, address indexed user);
    event ClaimFromTreasury(address indexed user, uint256 indexed amount);
    event Whitelisted(address account, bool whitelisted);
    event ForceExit(address indexed owner, uint256 indexed amount);

    uint256 constant STAKE_AMOUNT = 5e18;
    uint256 constant BUYER_STAKE_AMOUNT = 10e18;
    uint256 constant BUY_AMOUNT = 10e6;
    uint256 constant ORDER_ID = 0;
    uint256 constant ESAPEX12_USD_PRICE = 1e18;
    uint256 constant DAILY_TOKEN_SALES_INCREASE = 10e18;
    uint256 constant EXCESS_BUY_AMOUNT = 20e6;

    address public staker1 = makeAddr("staker1");
    address public staker2 = makeAddr("staker2");
    address public buyer = makeAddr("buyer");
    address public attacker = makeAddr("attacker");
    address public updater = makeAddr("updater");
    address public newOwner = makeAddr("newOwner");
    address public owner;
    uint256 public newSignerPrivateKey = 0x1234;
    address public newSigner = vm.addr(newSignerPrivateKey);

    using ECDSA for bytes32;

    uint256 public constant STARTING_USER_BALANCE = 500 ether;
    TransparentUpgradeableProxy transparentProxy;
    ERC20Mock public apexToken;
    ERC20Mock public usdtToken;
    address public apexAddr;
    address public usdtAddr;
    ESAPEX12 public esAPEX12;

    function setUp() public {
        DeployESAPEX12 deployer = new DeployESAPEX12();
        (transparentProxy, usdtAddr, apexAddr, owner) = deployer.run();

        apexToken = ERC20Mock(apexAddr);
        usdtToken = ERC20Mock(usdtAddr);

        esAPEX12 = ESAPEX12(address(transparentProxy));

        if (block.chainid == 31337) {
            vm.deal(owner, STARTING_USER_BALANCE);
        }
        ERC20Mock(apexToken).mint(owner, STARTING_USER_BALANCE);
        ERC20Mock(usdtToken).mint(buyer, STARTING_USER_BALANCE);
        ERC20Mock(usdtToken).mint(staker1, STARTING_USER_BALANCE);
    }

    // ESAPEX12 && BasicToken test
    function testInitializationOwner() public view {
        assertEq(esAPEX12.owner(), owner);
        console2.log(address(esAPEX12));
    }

    function testTransferOwnership() public {
        vm.startPrank(owner);
        esAPEX12.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(esAPEX12.owner(), newOwner);
    }

    function testOnlyOwnerCanTransferOwnership() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        esAPEX12.transferOwnership(attacker);
        vm.stopPrank();

        assertEq(esAPEX12.owner(), owner);
    }

    function testInitializationUsdtToken() public view {
        address usdtAddress = address(esAPEX12.usdtToken());
        assertEq(usdtAddress, address(usdtToken));
    }

    function testInitializationApeXToken() public view {
        address apexAddress = address(esAPEX12.apeXToken());
        assertEq(apexAddress, address(apexToken));
    }

    function testInitializationName() public view {
        assertEq(esAPEX12.name(), "esAPEX12");
    }

    function testInitializationSymbol() public view {
        assertEq(esAPEX12.symbol(), "esAPEX12");
    }

    function testInitializationPaused() public view {
        assertEq(esAPEX12.paused(), false);
    }

    function testSetPaused() public {
        vm.prank(owner);
        esAPEX12.pause();
        assertEq(esAPEX12.paused(), true);

        vm.prank(owner);
        esAPEX12.unpause();
        assertEq(esAPEX12.paused(), false);
    }

    function testSetPausedEmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit Paused(owner);

        vm.prank(esAPEX12.owner());
        esAPEX12.pause();
        vm.stopPrank();
    }

    function testOnlyOwnerCanSetPaused() public {
        vm.prank(attacker);
        vm.expectRevert();
        esAPEX12.pause();
    }

    modifier paused() {
        vm.prank(owner);
        esAPEX12.pause();
        _;
    }

    // InitalStakeable test
    function testSetisInitalStakingAllowed() public {
        vm.prank(owner);
        esAPEX12.setisInitalStakingAllowed(true);
        assertEq(esAPEX12.isInitalStakingAllowed(), true);

        vm.prank(owner);
        esAPEX12.setisInitalStakingAllowed(false);
        assertEq(esAPEX12.isInitalStakingAllowed(), false);
    }

    function testSetisInitalStakingAllowedNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        esAPEX12.setisInitalStakingAllowed(true);
    }

    modifier setisInitalStakingAllowed() {
        vm.prank(owner);
        esAPEX12.setisInitalStakingAllowed(true);
        _;
    }

    modifier setisInitalStakingNotAllowed() {
        vm.prank(owner);
        esAPEX12.setisInitalStakingAllowed(false);
        _;
    }

    function testStakeAPEX() public setisInitalStakingAllowed {
        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(owner),
            STARTING_USER_BALANCE - STAKE_AMOUNT
        );
        assertEq(apexToken.balanceOf(address(esAPEX12)), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);

        assertEq(esAPEX12.totalStaked(), STAKE_AMOUNT);
        assertEq(esAPEX12.apexTreasury(), STAKE_AMOUNT);
    }

    function testCantStakeAPEXPaused() public paused setisInitalStakingAllowed {
        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCantStakeAPEXWithInsufficientBalance()
        public
        setisInitalStakingAllowed
    {
        vm.startPrank(owner);
        apexToken.transfer(attacker, STARTING_USER_BALANCE);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);
        vm.expectRevert("Insufficient balance");
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCantStakeAPEXWithInsufficientAllowance()
        public
        setisInitalStakingAllowed
    {
        vm.startPrank(owner);
        vm.expectRevert("Insufficient allowance");
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCantStakeAPEXWithStakeZeroToken()
        public
        setisInitalStakingAllowed
    {
        vm.startPrank(owner);
        vm.expectRevert("Cannot stake zero tokens");
        esAPEX12.stakeAPEX(staker1, 0);
        vm.stopPrank();
    }

    function testCantStakeAPEXwithNotAllowed()
        public
        setisInitalStakingNotAllowed
    {
        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);
        vm.expectRevert(bytes4(keccak256("NotAllowed()")));
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testStakeAPEXEmitsEvent() public setisInitalStakingAllowed {
        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit InitalStakerApexStaked(staker1, STAKE_AMOUNT);
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
    }

    modifier stakeAPEX() {
        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT);
        esAPEX12.stakeAPEX(staker1, STAKE_AMOUNT);
        vm.stopPrank();
        _;
    }

    // LP Token test
    function testLPToken() public view {
        assertEq(esAPEX12.lpToken().name(), "APEX LP Token");
        assertEq(esAPEX12.lpToken().symbol(), "APEX-LP");
        assertEq(esAPEX12.lpToken().decimals(), 18);
        assertEq(esAPEX12.lpToken().totalSupply(), 0);
    }

    function testLPTokenWithStakeApex()
        public
        setisInitalStakingAllowed
        stakeAPEX
    {
        assertEq(esAPEX12.lpToken().totalSupply(), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker2), 0);
    }

    function testLPTokenCannotTransfer()
        public
        setisInitalStakingAllowed
        stakeAPEX
    {
        assertEq(esAPEX12.lpToken().totalSupply(), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);

        LPToken lpToken = esAPEX12.lpToken();

        vm.startPrank(staker1);
        vm.expectRevert("Transfer not allowed");
        lpToken.transfer(staker2, STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);

        lpToken.approve(staker2, STAKE_AMOUNT);
        assertEq(lpToken.allowance(staker1, staker2), STAKE_AMOUNT);
        vm.stopPrank();

        vm.startPrank(staker2);
        vm.expectRevert("Transfer not allowed");
        lpToken.transferFrom(staker1, staker2, STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testLPTokenSetWhitelist() public {
        LPToken lpToken = esAPEX12.lpToken();

        vm.startPrank(owner);

        vm.expectEmit(true, true, true, true);
        emit Whitelisted(staker1, true);
        lpToken.setWhitelist(staker1, true);
        assertEq(lpToken.isWhitelisted(staker1), true);

        vm.expectEmit(true, true, true, true);
        emit Whitelisted(staker1, false);
        lpToken.setWhitelist(staker1, false);
        assertEq(lpToken.isWhitelisted(staker1), false);
        vm.stopPrank();

        vm.startPrank(attacker);
        vm.expectRevert();
        lpToken.setWhitelist(attacker, true);
        vm.stopPrank();
    }

    function testLPTokenWhitelistTransfer()
        public
        setisInitalStakingAllowed
        stakeAPEX
    {
        assertEq(esAPEX12.lpToken().totalSupply(), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);

        LPToken lpToken = esAPEX12.lpToken();

        vm.startPrank(owner);
        lpToken.setWhitelist(staker1, true);
        assertEq(lpToken.isWhitelisted(staker1), true);
        vm.stopPrank();

        vm.startPrank(staker1);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker2), 0);
        lpToken.transfer(staker2, STAKE_AMOUNT);
        assertEq(esAPEX12.lpToken().balanceOf(staker1), 0);
        assertEq(esAPEX12.lpToken().balanceOf(staker2), STAKE_AMOUNT);
        vm.stopPrank();
    }

    // PriceUpdatable test
    function testSetSigner() public {
        vm.prank(owner);
        esAPEX12.setSigner(newSigner);
        assertEq(esAPEX12.signer(), newSigner);
    }

    function testSetSignerNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        esAPEX12.setSigner(newSigner);
    }

    function testSetSignerWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Zero address");
        esAPEX12.setSigner(address(0));
    }

    modifier setSigner() {
        vm.prank(owner);
        esAPEX12.setSigner(newSigner);
        _;
    }

    function testUpdatePrice() public setSigner {
        bytes32 message = keccak256(
            abi.encodePacked(
                updater,
                vm.getBlockTimestamp(),
                ESAPEX12_USD_PRICE,
                block.chainid
            )
        );

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(updater);
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );
        vm.stopPrank();

        assertEq(esAPEX12.currentPrice(), ESAPEX12_USD_PRICE);
    }

    function testUpdatePriceEmitsEvent() public setSigner {
        bytes32 message = keccak256(
            abi.encodePacked(
                updater,
                vm.getBlockTimestamp(),
                ESAPEX12_USD_PRICE,
                block.chainid
            )
        );

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, true, true);
        emit PriceUpdated(ESAPEX12_USD_PRICE, updater);
        vm.startPrank(updater);
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );
        vm.stopPrank();
    }

    function testCantUpdatePriceWithInvalidSignatureWithWrongKey()
        public
        setSigner
    {
        bytes32 message = keccak256(
            abi.encodePacked(
                updater,
                vm.getBlockTimestamp(),
                ESAPEX12_USD_PRICE,
                block.chainid
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(updater);
        vm.expectRevert("Illegal signature");
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE * 2,
            signature
        );
        vm.stopPrank();
    }

    function testCantUpdatePriceWithInvalidSignatureWithWrongData()
        public
        setSigner
    {
        bytes32 message = keccak256(
            abi.encodePacked(
                updater,
                vm.getBlockTimestamp(),
                ESAPEX12_USD_PRICE,
                block.chainid
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey * 2,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(updater);
        vm.expectRevert("Illegal signature");
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );
        vm.stopPrank();
    }

    function testCantUpdatePriceWithSameSignature() public setSigner {
        bytes32 message = keccak256(
            abi.encodePacked(
                updater,
                vm.getBlockTimestamp(),
                ESAPEX12_USD_PRICE,
                block.chainid
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(updater);
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );

        vm.expectRevert(
            "The price index should be newer than the current price index"
        );
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );
        vm.stopPrank();
    }

    modifier updatePrice() {
        vm.prank(owner);
        esAPEX12.setSigner(newSigner);
        bytes32 message = keccak256(
            abi.encodePacked(updater, ESAPEX12_USD_PRICE, block.chainid)
        );

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(
            message
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            newSignerPrivateKey,
            ethSignedMessageHash
        );
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startPrank(updater);
        esAPEX12.updatePrice(
            vm.getBlockTimestamp(),
            ESAPEX12_USD_PRICE,
            signature
        );
        vm.stopPrank();
        _;
    }

    // PriceValidatable test
    function testSetValidateTimeInterval() public {
        vm.prank(owner);
        esAPEX12.setValidateTimeInterval(8 hours);
        assertEq(esAPEX12.validateTimeInterval(), 8 hours);
    }

    function testSetValidateTimeIntervalNotOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        esAPEX12.setValidateTimeInterval(8 hours);
    }

    modifier setValidateTimeInterval() {
        vm.prank(esAPEX12.owner());
        esAPEX12.setValidateTimeInterval(3 hours);
        _;
    }

    // TokenSaleable test
    function testSetDailyTokenSalesIncrease() public {
        vm.startPrank(owner);
        esAPEX12.setDailyTokenSalesIncrease(DAILY_TOKEN_SALES_INCREASE);
        assertEq(
            esAPEX12.DAILY_TOKEN_SALES_INCREASE(),
            DAILY_TOKEN_SALES_INCREASE
        );
        vm.stopPrank();
    }

    function testSetDailyTokenSalesIncreaseNotOwner() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        esAPEX12.setDailyTokenSalesIncrease(DAILY_TOKEN_SALES_INCREASE);
        vm.stopPrank();
    }

    modifier setDailyTokenSalesIncrease() {
        vm.prank(owner);
        esAPEX12.setDailyTokenSalesIncrease(DAILY_TOKEN_SALES_INCREASE);
        _;
    }

    function testGetCurrentSalesLimit()
        public
        setDailyTokenSalesIncrease
        addApexToTreasury
    {
        // Arrange
        uint256 initialSalableQuantity = esAPEX12.currentSalesLimit();

        // Act
        vm.warp(block.timestamp + 1 days);
        console2.log(esAPEX12.getCurrentSalesLimit());

        // Assert
        uint256 newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        uint256 expectedIncrease = DAILY_TOKEN_SALES_INCREASE;
        assertEq(newSalableQuantity, initialSalableQuantity + expectedIncrease);

        // Act
        vm.warp(block.timestamp + 7 days);
        console2.log(esAPEX12.getCurrentSalesLimit());

        newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        assertEq(
            newSalableQuantity,
            initialSalableQuantity + (1 + 7) * expectedIncrease
        );
    }

    function testGetCurrentSalesLimitWithZeroApex()
        public
        setDailyTokenSalesIncrease
    {
        vm.warp(block.timestamp + 1 days);
        console2.log(esAPEX12.getCurrentSalesLimit());

        uint256 newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        assertEq(newSalableQuantity, 0);

        vm.warp(block.timestamp + 7 days);
        console2.log(esAPEX12.getCurrentSalesLimit());

        newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        assertEq(newSalableQuantity, 0);
    }

    function testGetCurrentSalesLimitWhenChangeDailyLimit()
        public
        setDailyTokenSalesIncrease
        addApexToTreasury
    {
        // Arrange
        uint256 initialSalableQuantity = esAPEX12.currentSalesLimit();

        // Act
        vm.warp(block.timestamp + 25 hours);

        // Assert
        uint256 newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        uint256 expectedIncrease = DAILY_TOKEN_SALES_INCREASE;
        assertEq(newSalableQuantity, initialSalableQuantity + expectedIncrease);

        // Act
        vm.warp(block.timestamp + 7 days);
        console2.log(esAPEX12.getCurrentSalesLimit());

        newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        assertEq(
            newSalableQuantity,
            initialSalableQuantity + (1 + 7) * expectedIncrease
        );

        vm.startPrank(owner);

        esAPEX12.setDailyTokenSalesIncrease(DAILY_TOKEN_SALES_INCREASE * 5);
        newSalableQuantity = esAPEX12.getCurrentSalesLimit();
        assertEq(
            newSalableQuantity,
            initialSalableQuantity + (1 + 7) * expectedIncrease
        );

        vm.stopPrank();
    }

    modifier addApexToTreasury() {
        vm.startPrank(owner);
        esAPEX12.setisInitalStakingAllowed(true);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT * 50);
        esAPEX12.stakeAPEX(owner, STAKE_AMOUNT * 50);

        // assertEq(esAPEX12.apexTreasury(), STAKE_AMOUNT*50);
        vm.stopPrank();
        _;
    }

    function testBuy()
        public
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 1 days);
        testUpdatePrice();

        // Act
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        uint256 esApex12Amount = esAPEX12.buy(BUY_AMOUNT);

        // Assert
        assertEq(esAPEX12.balanceOf(buyer), esApex12Amount);
        assertEq(
            esAPEX12.currentSalesLimit(),
            DAILY_TOKEN_SALES_INCREASE - esApex12Amount
        );

        assertEq(usdtToken.balanceOf(address(esAPEX12)), BUY_AMOUNT);
        assertEq(esAPEX12.usdtTreasury(), BUY_AMOUNT);
        vm.stopPrank();
    }

    function testBuyWithoutAllowance()
        public
        setDailyTokenSalesIncrease
        setValidateTimeInterval
    {
        // Arrange
        vm.warp(block.timestamp + 1 days);
        testUpdatePrice();

        // Act
        vm.startPrank(buyer);
        vm.expectRevert("Insufficient allowance");
        esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
    }

    function testBuyWithoutBalance()
        public
        setDailyTokenSalesIncrease
        setValidateTimeInterval
    {
        // Arrange
        vm.warp(block.timestamp + 1 days);
        testUpdatePrice();

        // Act
        vm.startPrank(buyer);
        usdtToken.transfer(owner, STARTING_USER_BALANCE);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        vm.expectRevert("Insufficient balance");
        esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
    }

    function testCantNotEnoughSalableQuantityBuy()
        public
        setValidateTimeInterval
        setDailyTokenSalesIncrease
    {
        ERC20Mock(usdtToken).mint(buyer, EXCESS_BUY_AMOUNT);

        vm.warp(block.timestamp + 1 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), EXCESS_BUY_AMOUNT);
        vm.expectRevert(bytes4(keccak256("NotEnoughSalesLimit()")));
        esAPEX12.buy(EXCESS_BUY_AMOUNT);
        vm.stopPrank();
    }

    function testCanBuyTwoDayLater()
        public
        setValidateTimeInterval
        setDailyTokenSalesIncrease
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        // Act
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), EXCESS_BUY_AMOUNT);
        uint256 esApex12Amount = esAPEX12.buy(EXCESS_BUY_AMOUNT);

        // Assert
        assertEq(esAPEX12.balanceOf(buyer), esApex12Amount);
        assertEq(
            esAPEX12.currentSalesLimit(),
            (DAILY_TOKEN_SALES_INCREASE * 2) - esApex12Amount
        );
        vm.stopPrank();
    }

    function testCannotBuyInvalidPrice()
        public
        setValidateTimeInterval
        setDailyTokenSalesIncrease
    {
        // Arrange
        vm.warp(block.timestamp + 20 hours);
        testUpdatePrice();
        vm.warp(block.timestamp + 4 hours);

        // Act
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        vm.expectRevert(bytes4(keccak256("InvalidPrice()")));
        esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
    }

    function testCanBuyValidPrice()
        public
        setValidateTimeInterval
        setDailyTokenSalesIncrease
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 22 hours);
        testUpdatePrice();
        vm.warp(block.timestamp + 2 hours);

        // Act
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
    }

    function testCantBuyPaused()
        public
        paused
        setValidateTimeInterval
        setDailyTokenSalesIncrease
    {
        // Arrange
        testUpdatePrice();
        vm.warp(block.timestamp + 1 days);

        // Act
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
    }

    modifier testBuyForApexTreasury() {
        testSetValidateTimeInterval();
        testSetDailyTokenSalesIncrease();
        vm.startPrank(owner);
        esAPEX12.setisInitalStakingAllowed(true);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT * 50);
        esAPEX12.stakeAPEX(owner, STAKE_AMOUNT * 50);
        vm.stopPrank();

        vm.warp(25 hours);
        testUpdatePrice();
        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), BUY_AMOUNT);
        uint256 esApex12Amount = esAPEX12.buy(BUY_AMOUNT);
        vm.stopPrank();
        _;
    }

    // Timelockable test
    function testCreateTimelock() public testBuyForApexTreasury {
        vm.startPrank(buyer);

        assertEq(esAPEX12.balanceOf(buyer), BUYER_STAKE_AMOUNT);
        esAPEX12.createTimelock(BUYER_STAKE_AMOUNT);
        assertEq(esAPEX12.balanceOf(buyer), 0);
        vm.stopPrank();
    }

    function testCannotCreateTimelockWhenPaused()
        public
        addApexToTreasury
        testBuyForApexTreasury
        paused
    {
        vm.startPrank(buyer);

        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.createTimelock(BUYER_STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCreateTimelockEmitsEvent() public testBuyForApexTreasury {
        vm.startPrank(buyer);

        vm.expectEmit(true, true, true, true);
        emit TimelockCreated(
            esAPEX12.timelockId(),
            buyer,
            BUYER_STAKE_AMOUNT,
            block.timestamp
        );
        esAPEX12.createTimelock(BUYER_STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testCreateTimelockWithZeroToken() public testBuyForApexTreasury {
        vm.startPrank(buyer);
        vm.expectRevert("Cannot timelock zero tokens");
        esAPEX12.createTimelock(0);
        vm.stopPrank();
    }

    function testCreateTimelockWithInsufficientBalance() public {
        vm.startPrank(buyer);
        vm.expectRevert("Insufficient balance");
        esAPEX12.createTimelock(BUYER_STAKE_AMOUNT);
        vm.stopPrank();
    }

    modifier createTimelock() {
        testBuy();
        vm.startPrank(buyer);
        esAPEX12.createTimelock(BUYER_STAKE_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testRedeemTimelock()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(buyer);
        vm.warp(block.timestamp + 365 days);

        assertEq(apexToken.balanceOf(address(esAPEX12)), STAKE_AMOUNT * 50);
        assertEq(esAPEX12.apexTreasury(), STAKE_AMOUNT * 50);

        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();

        assertEq(apexToken.balanceOf(buyer), BUYER_STAKE_AMOUNT);
        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 - BUYER_STAKE_AMOUNT
        );
        assertEq(
            esAPEX12.apexTreasury(),
            STAKE_AMOUNT * 50 - BUYER_STAKE_AMOUNT
        );
    }

    function testCannotRedeemTimelockWhenPaused()
        public
        setisInitalStakingAllowed
        createTimelock
        paused
    {
        vm.startPrank(buyer);

        vm.warp(block.timestamp + 365 days);

        assertEq(apexToken.balanceOf(address(esAPEX12)), STAKE_AMOUNT * 50);
        assertEq(esAPEX12.apexTreasury(), STAKE_AMOUNT * 50);

        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testRedeemTimelockEmitsEvent()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(buyer);

        vm.warp(block.timestamp + 365 days);

        vm.expectEmit(true, true, true, true);
        emit TimelockRedeemed(ORDER_ID, buyer);
        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testRedeemTimelockNotOwner()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(owner);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Only owner can redeem");
        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testRedeemTimelockInvalidId()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(buyer);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Invalid id");
        esAPEX12.redeemTimelock(ORDER_ID + 1);
        vm.stopPrank();
    }

    function testRedeemTimelockWithInLockPeriod()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(buyer);

        vm.expectRevert("Still in lock period");
        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testRedeemTimelockWithNotValid()
        public
        setisInitalStakingAllowed
        createTimelock
    {
        vm.startPrank(buyer);
        vm.warp(block.timestamp + 365 days);
        esAPEX12.redeemTimelock(ORDER_ID);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Not valid");
        esAPEX12.redeemTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testCancelTimelock()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(buyer);
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();

        assertEq(esAPEX12.balanceOf(buyer), BUYER_STAKE_AMOUNT);
    }

    function testCannotCancelTimelockWhenPause()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
        paused
    {
        vm.startPrank(buyer);
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testCancelTimelockEmitsEvent()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(buyer);
        vm.expectEmit(true, true, true, true);
        emit TimelockCancelled(ORDER_ID, buyer);
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testCancelTimelockNotOwner()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(owner);

        vm.expectRevert("Only owner can cancel");
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testCancelTimelockInvalidId()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(owner);

        vm.expectRevert("Invalid id");
        esAPEX12.cancelTimelock(ORDER_ID + 1);
        vm.stopPrank();
    }

    function testCancelTimelockNotInLockPeriod()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(buyer);

        vm.warp(block.timestamp + 365 days);

        vm.expectRevert("Not in lock period");
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();
    }

    function testCancelTimelockNotValid()
        public
        setisInitalStakingAllowed
        stakeAPEX
        createTimelock
    {
        vm.startPrank(buyer);

        esAPEX12.cancelTimelock(ORDER_ID);

        vm.expectRevert("Not valid");
        esAPEX12.cancelTimelock(ORDER_ID);
        vm.stopPrank();
    }

    // InitalStakeable test
    function testcalcClaimableAmount()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);
        vm.stopPrank();

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT * 2);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT + 5e18);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 + 15e18
        );
        assertEq(esAPEX12.apexTreasury(), STAKE_AMOUNT * 50 + 15e18);

        assertEq(usdtToken.balanceOf(address(esAPEX12)), 15e6);
        assertEq(esAPEX12.usdtTreasury(), 15e6);

        // before treasury increases
        uint256 beforeTreasuryBalance = esAPEX12.accUsdtTreasury();
        uint256 beforeTotalStaked = esAPEX12.totalStaked();
        uint256 beforeTotalStaker1ClaimAmount = esAPEX12.totalClaimAmount(
            staker1
        );

        uint256 beforeTotalStaker2ClaimAmount = esAPEX12.totalClaimAmount(
            staker2
        );

        assertEq(beforeTotalStaker1ClaimAmount, 0);
        assertEq(beforeTotalStaker1ClaimAmount, 0);

        uint256 beforeStaker1Stake = esAPEX12.initalStakerApexAmount(staker1);
        uint256 beforeStaker2Stake = esAPEX12.initalStakerApexAmount(staker2);

        assertEq(beforeStaker1Stake, STAKE_AMOUNT);
        assertEq(beforeStaker2Stake, STAKE_AMOUNT * 2);

        uint256 beforeTotalStaker1WithdrawalLimit = (beforeTreasuryBalance *
            beforeStaker1Stake) / beforeTotalStaked;
        uint256 beforeStaker1ClaimableAmount = beforeTotalStaker1WithdrawalLimit -
                beforeTotalStaker1ClaimAmount;

        uint256 beforeTotalStaker2WithdrawalLimit = (beforeTreasuryBalance *
            beforeStaker2Stake) / beforeTotalStaked;
        uint256 beforeStaker2ClaimableAmount = beforeTotalStaker2WithdrawalLimit -
                beforeTotalStaker2ClaimAmount;

        // Act && Assert
        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            beforeStaker1ClaimableAmount
        );

        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            beforeStaker2ClaimableAmount
        );

        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            (15e6 * 5e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            (15e6 * 10e18) / (STAKE_AMOUNT * 50 + 15e18)
        );

        // after treasury increases
        // Arrange

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 4e6);
        esAPEX12.buy(4e6);
        vm.stopPrank();

        uint256 afterTreasuryBalance = esAPEX12.accUsdtTreasury();
        uint256 afterTotalStaked = esAPEX12.totalStaked();
        uint256 afterTotalStaker1ClaimAmount = esAPEX12.totalClaimAmount(
            staker1
        );
        uint256 afterTotalStaker2ClaimAmount = esAPEX12.totalClaimAmount(
            staker2
        );

        assertEq(afterTotalStaker1ClaimAmount, 0);
        assertEq(afterTotalStaker2ClaimAmount, 0);

        uint256 afterStaker1Stake = esAPEX12.initalStakerApexAmount(staker1);
        uint256 afterStaker2Stake = esAPEX12.initalStakerApexAmount(staker2);

        assertEq(afterStaker1Stake, STAKE_AMOUNT);
        assertEq(afterStaker2Stake, STAKE_AMOUNT * 2);

        uint256 afterTotalStaker1WithdrawalLimit = (afterTreasuryBalance *
            afterStaker1Stake) / afterTotalStaked;
        uint256 afterStaker1ClaimableAmount = afterTotalStaker1WithdrawalLimit -
            afterTotalStaker1ClaimAmount;

        uint256 afterTotalStaker2WithdrawalLimit = (afterTreasuryBalance *
            afterStaker2Stake) / afterTotalStaked;
        uint256 afterStaker2ClaimableAmount = afterTotalStaker2WithdrawalLimit -
            afterTotalStaker2ClaimAmount;

        // // Act && Assert
        // Act && Assert
        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            afterStaker1ClaimableAmount
        );

        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            afterStaker2ClaimableAmount
        );

        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            (19e6 * 5e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            (19e6 * 10e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
    }

    function testClaimFromTreasury()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT * 2);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT * 2);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 + 15e18
        );

        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            (15e6 * 5e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            (15e6 * 10e18) / (STAKE_AMOUNT * 50 + 15e18)
        );

        vm.startPrank(staker2);
        esAPEX12.claimFromTreasury(1e5);
        vm.stopPrank();

        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            (15e6 * 5e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            (15e6 * 10e18) / (STAKE_AMOUNT * 50 + 15e18) - 1e5
        );

        vm.startPrank(staker2);
        esAPEX12.claimFromTreasury(2e5);
        vm.stopPrank();

        assertEq(
            esAPEX12.calcClaimableAmount(staker1),
            (15e6 * 5e18) / (STAKE_AMOUNT * 50 + 15e18)
        );
        assertEq(
            esAPEX12.calcClaimableAmount(staker2),
            (15e6 * 10e18) / (STAKE_AMOUNT * 50 + 15e18) - 3e5
        );

        uint256 treasuryBalance = esAPEX12.accUsdtTreasury();
        uint256 totalStaked = esAPEX12.totalStaked();
        uint256 totalClaimAmount = esAPEX12.totalClaimAmount(staker2);

        uint256 stakerStake = esAPEX12.initalStakerApexAmount(staker2);

        uint256 totalWithdrawalLimit = (treasuryBalance * stakerStake) /
            totalStaked;

        int256(totalWithdrawalLimit) - int256(totalClaimAmount);

        assertEq(usdtToken.balanceOf(staker2), 3e5);

        assertEq(usdtToken.balanceOf(address(esAPEX12)), 15e6 - 3e5);
        assertEq(esAPEX12.usdtTreasury(), 15e6 - 3e5);
    }

    function testCannotClaimFromTreasuryWhenPause()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);
        vm.stopPrank();

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT * 2);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT * 2);
        vm.stopPrank();

        vm.startPrank(owner);
        esAPEX12.pause();
        vm.stopPrank();

        vm.startPrank(staker2);
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        esAPEX12.claimFromTreasury(1e6);
        vm.stopPrank();
    }

    function testClaimFromTreasuryWithZeroToken()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);
        vm.stopPrank();

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT + 5e18);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT + 5e18);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 + 15e18
        );

        vm.prank(staker2);
        vm.expectRevert("Cannot withdraw zero tokens");
        esAPEX12.claimFromTreasury(0);
    }

    function testClaimFromTreasuryWithExceedsLimit()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 2 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);
        vm.stopPrank();

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT + 5e18);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT + 5e18);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 + 15e18
        );

        vm.prank(staker2);
        vm.expectRevert("Withdrawal amount exceeds limit");
        esAPEX12.claimFromTreasury(100e18);
    }

    function testClaimFromTreasuryEmitsEvent()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 20 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        esAPEX12.buy(15e6);
        vm.stopPrank();

        vm.startPrank(owner);
        apexToken.approve(address(esAPEX12), STAKE_AMOUNT + 5e18);
        esAPEX12.stakeAPEX(staker2, STAKE_AMOUNT + 5e18);
        vm.stopPrank();

        assertEq(
            apexToken.balanceOf(address(esAPEX12)),
            STAKE_AMOUNT * 50 + 15e18
        );

        vm.prank(staker1);
        vm.expectEmit(true, true, true, true);
        emit ClaimFromTreasury(staker1, 1e5);
        esAPEX12.claimFromTreasury(1e5);
        vm.stopPrank();
    }

    function testForceExit()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 20 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        uint256 buyTokenNumber = esAPEX12.buy(15e6);
        esAPEX12.createTimelock(buyTokenNumber);
        vm.stopPrank();

        // Act
        vm.startPrank(owner);
        esAPEX12.forceExit(owner);
        vm.stopPrank();

        // Asset
        assertEq(esAPEX12.nonIssueApexTreasury(), 0);
        assertEq(esAPEX12.apexTreasury(), buyTokenNumber);
    }

    function testForceExitEmitsEvent()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        vm.warp(block.timestamp + 20 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        uint256 buyTokenNumber = esAPEX12.buy(15e6);
        esAPEX12.createTimelock(buyTokenNumber);
        vm.stopPrank();

        uint256 expectedWithdrawableAmount = esAPEX12.apexTreasury() -
            buyTokenNumber;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ForceExit(owner, expectedWithdrawableAmount);
        esAPEX12.forceExit(owner);
        vm.stopPrank();
    }

    function testForceExitCantBuy()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 20 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        uint256 buyTokenNumber = esAPEX12.buy(15e6);
        esAPEX12.createTimelock(buyTokenNumber);
        vm.stopPrank();

        // Act
        vm.startPrank(owner);
        esAPEX12.forceExit(owner);
        vm.stopPrank();

        // Asset
        assertEq(esAPEX12.nonIssueApexTreasury(), 0);
        assertEq(esAPEX12.apexTreasury(), buyTokenNumber);

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        vm.expectRevert();
        esAPEX12.buy(15e6);
        vm.stopPrank();
    }

    function testForceExitIsInitalStakingAllowedEqualFalse()
        public
        setisInitalStakingAllowed
        setDailyTokenSalesIncrease
        setValidateTimeInterval
        stakeAPEX
        addApexToTreasury
    {
        // Arrange
        vm.warp(block.timestamp + 20 days);
        testUpdatePrice();

        vm.startPrank(buyer);
        usdtToken.approve(address(esAPEX12), 15e6);
        uint256 buyTokenNumber = esAPEX12.buy(15e6);
        esAPEX12.createTimelock(buyTokenNumber);
        vm.stopPrank();

        // Act
        vm.startPrank(owner);
        esAPEX12.forceExit(owner);
        vm.stopPrank();

        // Asset
        assertEq(esAPEX12.nonIssueApexTreasury(), 0);
        assertEq(esAPEX12.apexTreasury(), buyTokenNumber);
        assertEq(esAPEX12.isInitalStakingAllowed(), false);
    }
}
