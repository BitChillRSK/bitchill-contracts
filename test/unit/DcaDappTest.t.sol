//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {DcaManagerAccessControl} from "../../src/DcaManagerAccessControl.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {IDocHandler} from "../../src/interfaces/IDocHandler.sol";
import {ICoinPairPrice} from "../../src/interfaces/ICoinPairPrice.sol";
import {TropykusDocHandlerMoc} from "../../src/TropykusDocHandlerMoc.sol";
import {SovrynDocHandlerMoc} from "../../src/SovrynDocHandlerMoc.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {OperationsAdmin} from "../../src/OperationsAdmin.sol";
import {IOperationsAdmin} from "../../src/interfaces/IOperationsAdmin.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import {DexHelperConfig} from "../../script/DexHelperConfig.s.sol";
import {DeployDexSwaps} from "../../script/DeployDexSwaps.s.sol";
import {DeployMocSwaps} from "../../script/DeployMocSwaps.s.sol";
import {MockStablecoin} from "../mocks/MockStablecoin.sol";
import {ILendingToken} from "../interfaces/ILendingToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";
import {MockWrbtcToken} from "../mocks/MockWrbtcToken.sol";
import {MockSwapRouter02} from "../mocks/MockSwapRouter02.sol";
import "../../script/Constants.sol";
import "./TestsHelper.t.sol";
import {IkToken} from "../../src/interfaces/IkToken.sol";
import {IiSusdToken} from "../../src/interfaces/IiSusdToken.sol";

contract DcaDappTest is Test {
    DcaManager dcaManager;
    MockMocProxy mocProxy;
    IDocHandler docHandler;
    OperationsAdmin operationsAdmin;
    MockStablecoin stablecoin;
    ILendingToken lendingToken;
    MockWrbtcToken wrBtcToken;
    FeeCalculator feeCalculator;
    
    // Helper configs from deployment
    MocHelperConfig mocHelperConfig;
    DexHelperConfig dexHelperConfig;

    // Stablecoin configuration
    string stablecoinType;

    address USER = makeAddr(USER_STRING);
    address OWNER = makeAddr(OWNER_STRING);
    address ADMIN = makeAddr(ADMIN_STRING);
    address SWAPPER = makeAddr(SWAPPER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    uint256 constant STARTING_RBTC_USER_BALANCE = 10 ether; // 10 rBTC
    uint256 constant RBTC_TO_MINT_DOC = 0.2 ether; // 0.2 BTC

    // Fixed constants for all stablecoin types
    uint256 constant USER_TOTAL_AMOUNT = 20000 ether;
    uint256 constant AMOUNT_TO_DEPOSIT = 2000 ether;
    uint256 constant AMOUNT_TO_SPEND = 200 ether;

    uint256 constant SCHEDULE_INDEX = 0;
    uint256 constant NUM_OF_SCHEDULES = 5;
    
    string swapType = vm.envString("SWAP_TYPE");
    bool isMocSwaps = keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"));
    bool isDexSwaps = keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"));
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address docHandlerAddress;
    uint256 s_lendingProtocolIndex;
    uint256 s_btcPrice;
    ICoinPairPrice mocOracle;
    address constant MOC_ORACLE_MAINNET = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
    address constant MOC_ORACLE_TESTNET = 0xbffBD993FF1d229B0FfE55668F2009d20d4F7C5f;
    address constant MOC_IN_RATE_MAINNET = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
    address constant MOC_IN_RATE_TESTNET = 0x76790f846FAAf44cf1B2D717d0A6c5f6f5152B60;
    address DUMMY_COMMISSION_RECEIVER = makeAddr("Dummy commission receiver");

    //////////////////////
    // Events ////////////
    //////////////////////

    // DcaManager
    event DcaManager__TokenBalanceUpdated(address indexed token, bytes32 indexed scheduleId, uint256 indexed amount);
    event DcaManager__DcaScheduleCreated(
        address indexed user,
        address indexed token,
        bytes32 indexed scheduleId,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );
    event DcaManager__DcaScheduleUpdated(
        address indexed user,
        address indexed token,
        bytes32 indexed scheduleId,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );

    // TokenHandler
    event TokenHandler__TokenDeposited(address indexed token, address indexed user, uint256 indexed amount);
    event TokenHandler__TokenWithdrawn(address indexed token, address indexed user, uint256 indexed amount);

    // IPurchaseRbtc
    event PurchaseRbtc__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 rBtcBought,
        bytes32 indexed scheduleId,
        uint256 amountSpent
    );
    event PurchaseRbtc__SuccessfulRbtcBatchPurchase(
        address indexed token, uint256 indexed totalPurchasedRbtc, uint256 indexed totalDocAmountSpent
    );

    // OperationsAdmin
    event OperationsAdmin__TokenHandlerUpdated(
        address indexed token, uint256 indexed lendinProtocolIndex, address indexed newHandler
    );

    //MockMocProxy
    event MockMocProxy__DocRedeemed(address indexed user, uint256 docAmount, uint256 btcAmount);

    //TokenLending
    event TokenLending__WithdrawalAmountAdjusted(
        address indexed user, uint256 indexed originalAmount, uint256 indexed adjustedAmount
    );

    modifier onlyDexSwaps() {
        if (!isDexSwaps) {
            console.log("Skipping test: only applicable for dexSwaps");
            return;
        }
        _;
    }

    modifier onlyMocSwaps() {
        if (!isMocSwaps) {
            console.log("Skipping test: only applicable for mocSwaps");
            return;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            UNIT TESTS SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        // Initialize stablecoin type from environment or use default
        try vm.envString("STABLECOIN_TYPE") returns (string memory coinType) {
            stablecoinType = coinType;
        } catch {
            stablecoinType = DEFAULT_STABLECOIN;
        }
        
        bool isSovryn = keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked(SOVRYN_STRING));
        bool isUSDRIF = keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("USDRIF"));
        
        // Skip test if Sovryn + USDRIF combination (not supported)
        if (isSovryn && isUSDRIF) {
            console.log("Skipping test: USDRIF is not supported by Sovryn");
            vm.skip(true);
            return;
        }
        
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked(TROPYKUS_STRING))) {
            s_lendingProtocolIndex = TROPYKUS_INDEX;
        } else if (isSovryn) {
            s_lendingProtocolIndex = SOVRYN_INDEX;
        } else {
            revert("Lending protocol not allowed");
        }
        
        // Deal rBTC funds to user
        vm.deal(USER, STARTING_RBTC_USER_BALANCE);
        s_btcPrice = BTC_PRICE;

        if (isMocSwaps) {
            DeployMocSwaps deployContracts = new DeployMocSwaps();
            (operationsAdmin, docHandlerAddress, dcaManager, mocHelperConfig) = deployContracts.run();
            docHandler = IDocHandler(docHandlerAddress);
            MocHelperConfig.NetworkConfig memory networkConfig = mocHelperConfig.getActiveNetworkConfig();

            address docTokenAddress = mocHelperConfig.getStablecoinAddress();
            address mocProxyAddress = networkConfig.mocProxyAddress;

            stablecoin = MockStablecoin(docTokenAddress);
            mocProxy = MockMocProxy(mocProxyAddress);

            // Give the MoC proxy contract allowance
            stablecoin.approve(mocProxyAddress, AMOUNT_TO_DEPOSIT);

            // Mint stablecoin for the user
            if (block.chainid == ANVIL_CHAIN_ID) {
                // Local tests
                // Deal rBTC funds to MoC contract
                vm.deal(mocProxyAddress, 1000 ether);

                // Give the MoC proxy contract allowance to move stablecoin from docHandler
                // This is necessary for local tests because of how the mock contract works, but not for the live contract
                vm.prank(address(docHandler));
                stablecoin.approve(mocProxyAddress, type(uint256).max);
                stablecoin.mint(USER, USER_TOTAL_AMOUNT);
            } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
                // Fork tests
                vm.store(
                    MOC_IN_RATE_MAINNET,
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );

                // Fork tests - use token holders instead of minting
                if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("DOC"))) {
                    // Set USER to DOC holder address
                    USER = DOC_HOLDER;
                } else if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("USDRIF"))) {
                    // Set USER to USDRIF holder address
                    USER = USDRIF_HOLDER;
                }
                
                // Get BTC price from oracle
                mocOracle = ICoinPairPrice(MOC_ORACLE_MAINNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
                vm.store(
                    address(MOC_IN_RATE_TESTNET),
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );

                // Fork tests - use token holders instead of minting
                if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("DOC"))) {
                    // Set USER to DOC holder address
                    USER = DOC_HOLDER_TESTNET;
                } else if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("USDRIF"))) {
                    // Set USER to USDRIF holder address
                    USER = USDRIF_HOLDER;
                }

                mocOracle = ICoinPairPrice(MOC_ORACLE_TESTNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            }
        } else if (isDexSwaps) {
            DeployDexSwaps deployContracts = new DeployDexSwaps();
            (operationsAdmin, docHandlerAddress, dcaManager, dexHelperConfig) = deployContracts.run();
            docHandler = IDocHandler(docHandlerAddress);
            
            address stablecoinAddress = dexHelperConfig.getStablecoinAddress();
            address wrBtcTokenAddress = dexHelperConfig.getActiveNetworkConfig().wrbtcTokenAddress;
            address swapRouter02Address = dexHelperConfig.getActiveNetworkConfig().swapRouter02Address;
            address mocProxyAddress = dexHelperConfig.getActiveNetworkConfig().mocProxyAddress;

            stablecoin = MockStablecoin(stablecoinAddress);
            wrBtcToken = MockWrbtcToken(wrBtcTokenAddress);
            mocProxy = MockMocProxy(mocProxyAddress);

            // Mint stablecoin for the user
            if (block.chainid == ANVIL_CHAIN_ID) {
                // Local tests
                stablecoin.mint(USER, USER_TOTAL_AMOUNT);
                // Deal 1000 rBTC to the mock SwapRouter02 contract, so that it can deposit rBTC on the mock WRBTC contract
                // to simulate that the DocHandlerDex contract has received WRBTC after calling the `exactInput()` function
                vm.deal(swapRouter02Address, 1000 ether);
            } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
                vm.store(
                    address(MOC_IN_RATE_MAINNET),
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );
                // vm.prank(USER);
                // // Use the appropriate mint function based on token type
                // (bool success, ) = address(mocProxy).call{value: 0.21 ether}(
                //     abi.encodeWithSignature(string(abi.encodePacked(tokenConfig.mintFunctionName, "(uint256)")), RBTC_TO_MINT_DOC)
                // );
                // require(success, "Mint function call failed");
                
                // Fork tests - use token holders instead of minting
                if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("DOC"))) {
                    // Set USER to DOC holder address
                    USER = DOC_HOLDER;
                } else if (keccak256(abi.encodePacked(stablecoinType)) == keccak256(abi.encodePacked("USDRIF"))) {
                    // Set USER to USDRIF holder address
                    USER = USDRIF_HOLDER;
                }

                mocOracle = ICoinPairPrice(MOC_ORACLE_MAINNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            // } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
            //     vm.store(
            //         address(MOC_IN_RATE_TESTNET),
            //         bytes32(uint256(214)),
            //         bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
            //     );
            //     vm.prank(USER);
            //     // Use the appropriate mint function based on token type
            //     (bool success, ) = address(mocProxy).call{value: 0.21 ether}(
            //         abi.encodeWithSignature(string(abi.encodePacked(tokenConfig.mintFunctionName, "(uint256)")), RBTC_TO_MINT_DOC)
            //     );
            //     require(success, "Mint function call failed");

            //     mocOracle = ICoinPairPrice(MOC_ORACLE_TESTNET);
            //     s_btcPrice = mocOracle.getPrice() / 1e18;
            }
        } else {
            revert("Invalid deploy environment");
        }

        // Set the lending token based on protocol and current stablecoin
        lendingToken = ILendingToken(getLendingTokenAddress(stablecoinType, s_lendingProtocolIndex));

        if (address(lendingToken) == address(0)) {
            // Skip this test instead of letting it fail
            vm.skip(true);
            return;
        }

        // FeeCalculator helper test contract
        feeCalculator = new FeeCalculator();

        // Set roles
        vm.prank(OWNER);
        operationsAdmin.setAdminRole(ADMIN);
        vm.startPrank(ADMIN);
        operationsAdmin.setSwapperRole(SWAPPER);
        // Add Troypkus and Sovryn as allowed lending protocols
        operationsAdmin.addOrUpdateLendingProtocol(TROPYKUS_STRING, 1);
        operationsAdmin.addOrUpdateLendingProtocol(SOVRYN_STRING, 2);
        vm.stopPrank();

        // Add tokenHandler
        vm.expectEmit(true, true, true, false);
        emit OperationsAdmin__TokenHandlerUpdated(address(stablecoin), s_lendingProtocolIndex, address(docHandler));
        vm.prank(ADMIN);
        operationsAdmin.assignOrUpdateTokenHandler(address(stablecoin), s_lendingProtocolIndex, address(docHandler));

        // The starting point of the tests is that the user has already deposited stablecoin (so withdrawals can also be tested without much hassle)
        vm.startPrank(USER);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        dcaManager.createDcaSchedule(
            address(stablecoin), AMOUNT_TO_DEPOSIT, AMOUNT_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      UNIT TESTS COMMON FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositDoc() internal returns (uint256, uint256) {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length - 1)
        );
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenDeposited(address(stablecoin), USER, AMOUNT_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit DcaManager__TokenBalanceUpdated(address(stablecoin), scheduleId, 2 * AMOUNT_TO_DEPOSIT); // 2 *, since a previous deposit is made in the setup
        dcaManager.depositToken(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        vm.stopPrank();
        return (userBalanceAfterDeposit, userBalanceBeforeDeposit);
    }

    function withdrawDoc() internal {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false); // Amounts may not match to the last wei, so third parameter is false
        emit TokenHandler__TokenWithdrawn(address(stablecoin), USER, AMOUNT_TO_DEPOSIT);
        dcaManager.withdrawToken(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_DEPOSIT);
        uint256 remainingAmount = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        assertEq(remainingAmount, 0);
        vm.stopPrank();
    }

    function createSeveralDcaSchedules() internal {
        vm.startPrank(USER);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        uint256 docToDeposit = AMOUNT_TO_DEPOSIT / NUM_OF_SCHEDULES;
        uint256 purchaseAmount = AMOUNT_TO_SPEND / NUM_OF_SCHEDULES;
        // Delete the schedule created in setUp to have all five schedules with the same amounts
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length - 1)
        );
        dcaManager.deleteDcaSchedule(address(stablecoin), scheduleId);
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = SCHEDULE_INDEX + i;
            uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
            uint256 userBalanceBeforeDeposit;
            if (dcaManager.getMyDcaSchedules(address(stablecoin)).length > scheduleIndex) {
                userBalanceBeforeDeposit = dcaManager.getMyScheduleTokenBalance(address(stablecoin), scheduleIndex);
            } else {
                userBalanceBeforeDeposit = 0;
            }
            scheduleId = keccak256(
                abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length)
            );
            vm.expectEmit(true, true, true, true);
            emit DcaManager__DcaScheduleCreated(
                USER, address(stablecoin), scheduleId, docToDeposit, purchaseAmount, purchasePeriod
            );
            dcaManager.createDcaSchedule(
                address(stablecoin), docToDeposit, purchaseAmount, purchasePeriod, s_lendingProtocolIndex
            );
            uint256 userBalanceAfterDeposit = dcaManager.getMyScheduleTokenBalance(address(stablecoin), scheduleIndex);
            assertEq(docToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
            assertEq(purchaseAmount, dcaManager.getMySchedulePurchaseAmount(address(stablecoin), scheduleIndex));
            assertEq(purchasePeriod, dcaManager.getMySchedulePurchasePeriod(address(stablecoin), scheduleIndex));
        }
        vm.stopPrank();
    }

    function makeSinglePurchase() internal {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        IDcaManager.DcaDetails[] memory dcaDetails = dcaManager.getMyDcaSchedules(address(stablecoin));
        vm.stopPrank();

        uint256 fee = feeCalculator.calculateFee(AMOUNT_TO_SPEND);
        uint256 netPurchaseAmount = AMOUNT_TO_SPEND - fee;

        if (block.chainid == ANVIL_CHAIN_ID && isMocSwaps) {
            vm.expectEmit(true, true, true, true);
        } else {
            vm.expectEmit(true, true, true, false); // Amounts may not match to the last wei on fork tests
        }
        emit PurchaseRbtc__RbtcBought(
            USER,
            address(stablecoin),
            netPurchaseAmount / s_btcPrice,
            dcaDetails[SCHEDULE_INDEX].scheduleId,
            netPurchaseAmount
        );
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, dcaDetails[SCHEDULE_INDEX].scheduleId);

        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();

        // Check that stablecoin was subtracted and rBTC was added to user's balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, AMOUNT_TO_SPEND);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(rbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase, netPurchaseAmount / s_btcPrice);
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            rbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase,
            netPurchaseAmount / s_btcPrice,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
        );
        // }
    }

    function makeSeveralPurchasesWithSeveralSchedules() internal returns (uint256 totalDocSpent) {
        // createSeveralDcaSchedules();

        uint8 numOfPurchases = 5;
        uint256 totalDocRedeemed;

        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = i;
            vm.startPrank(USER);
            uint256 schedulePurchaseAmount = dcaManager.getMySchedulePurchaseAmount(address(stablecoin), scheduleIndex);
            uint256 schedulePurchasePeriod = dcaManager.getMySchedulePurchasePeriod(address(stablecoin), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount);
            uint256 netPurchaseAmount = schedulePurchaseAmount - fee;

            for (uint8 j; j < numOfPurchases; ++j) {
                vm.startPrank(USER);
                uint256 docBalanceBeforePurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), scheduleIndex);
                uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
                bytes32 scheduleId = dcaManager.getScheduleId(USER, address(stablecoin), scheduleIndex);
                vm.stopPrank();
                
                vm.prank(SWAPPER);
                dcaManager.buyRbtc(USER, address(stablecoin), scheduleIndex, scheduleId);
                
                vm.startPrank(USER);
                uint256 docBalanceAfterPurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), scheduleIndex);
                uint256 RbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
                vm.stopPrank();
                
                // Check that stablecoin was subtracted and rBTC was added to user's balances
                assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, schedulePurchaseAmount);
                assertApproxEqRel(
                    RbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase,
                    netPurchaseAmount / s_btcPrice,
                    MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.75% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
                );

                totalDocSpent += netPurchaseAmount;
                totalDocRedeemed += schedulePurchaseAmount;

                vm.warp(block.timestamp + schedulePurchasePeriod);
            }
        }
        
        vm.prank(USER);
        assertApproxEqRel(
            IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(),
            totalDocSpent / s_btcPrice,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.75% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
        );
        
        return totalDocSpent;
    }

    function makeBatchPurchasesOneUser() internal {
        uint256 prevDocHandlerBalance;

        if (isMocSwaps) {
            prevDocHandlerBalance = address(docHandler).balance;
        } else if (isDexSwaps) {
            prevDocHandlerBalance = wrBtcToken.balanceOf(address(docHandler));
        }

        vm.prank(USER);
        uint256 userAccumulatedRbtcPrev = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        address[] memory users = new address[](NUM_OF_SCHEDULES);
        uint256[] memory scheduleIndexes = new uint256[](NUM_OF_SCHEDULES);
        uint256[] memory purchaseAmounts = new uint256[](NUM_OF_SCHEDULES);
        uint256[] memory purchasePeriods = new uint256[](NUM_OF_SCHEDULES);
        bytes32[] memory scheduleIds = new bytes32[](NUM_OF_SCHEDULES);

        uint256 totalNetPurchaseAmount;

        // Create the arrays for the batch purchase (in production, this is done in the back end)
        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = i;
            vm.startPrank(USER);
            uint256 schedulePurchaseAmount = dcaManager.getMySchedulePurchaseAmount(address(stablecoin), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount);
            totalNetPurchaseAmount += schedulePurchaseAmount - fee;

            users[i] = USER; // Same user for has 5 schedules due for a purchase in this scenario
            scheduleIndexes[i] = i;
            vm.startPrank(OWNER);
            purchaseAmounts[i] = dcaManager.getDcaSchedules(users[0], address(stablecoin))[i].purchaseAmount;
            purchasePeriods[i] = dcaManager.getDcaSchedules(users[0], address(stablecoin))[i].purchasePeriod;
            scheduleIds[i] = dcaManager.getDcaSchedules(users[0], address(stablecoin))[i].scheduleId;
            vm.stopPrank();
        }
        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            vm.expectEmit(false, false, false, false);
            emit PurchaseRbtc__RbtcBought(USER, address(stablecoin), 0, scheduleIds[i], 0); // Never mind the actual values on this test
        }

        vm.expectEmit(true, false, false, false); // the amount of rBTC purchased won't match exactly neither the amount of stablecoin spent in the case of Sovryn due to rounding errors

        if (isMocSwaps) {
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(stablecoin), totalNetPurchaseAmount / s_btcPrice, totalNetPurchaseAmount
            );
        } else if (isDexSwaps) {
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(stablecoin), (totalNetPurchaseAmount * 995) / (1000 * s_btcPrice), totalNetPurchaseAmount
            );
        }

        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(stablecoin),
            scheduleIndexes,
            scheduleIds,
            purchaseAmounts,
            s_lendingProtocolIndex
        );

        uint256 postDocHandlerBalance;

        if (isMocSwaps) {
            postDocHandlerBalance = address(docHandler).balance;
        } else if (isDexSwaps) {
            postDocHandlerBalance = wrBtcToken.balanceOf(address(docHandler));
        }

        assertApproxEqRel(
            postDocHandlerBalance - prevDocHandlerBalance,
            totalNetPurchaseAmount / s_btcPrice,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );

        vm.prank(USER);
        uint256 userAccumulatedRbtcPost = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();

        assertApproxEqRel(
            userAccumulatedRbtcPost - userAccumulatedRbtcPrev,
            totalNetPurchaseAmount / s_btcPrice,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );

        vm.warp(block.timestamp + 5 weeks); // warp to a time far in the future so all schedules are long due for a new purchase
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(stablecoin),
            scheduleIndexes,
            scheduleIds,
            purchaseAmounts,
            s_lendingProtocolIndex
        );
        
        uint256 postDocHandlerBalance2;

        if (isMocSwaps) {
            postDocHandlerBalance2 = address(docHandler).balance;
        } else if (isDexSwaps) {
            postDocHandlerBalance2 = wrBtcToken.balanceOf(address(docHandler));
        }

        assertApproxEqRel(
            postDocHandlerBalance2 - postDocHandlerBalance,
            totalNetPurchaseAmount / s_btcPrice,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );
    }

    function updateExchangeRate(uint256 secondsPassed) internal {
        vm.roll(block.number + secondsPassed / 30); // Jump to secondsPassed seconds (30 seconds per block) into the future so that some interest has been generated.
        vm.warp(block.timestamp + secondsPassed);

        address newUser = makeAddr("Lending protocol new user");

        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            vm.prank(USER);
            stablecoin.transfer(newUser, 100 ether);
            vm.startPrank(newUser);
            stablecoin.approve(address(lendingToken), 100 ether);
            console.log("Exchange rate before stablecoin deposit:", lendingToken.exchangeRateStored());
            lendingToken.mint(100 ether);
            console.log("Exchange rate after stablecoin deposit:", lendingToken.exchangeRateStored());
            vm.stopPrank();
        }
        // else if (s_lendingProtocolIndex == SOVRYN_INDEX) {
        //         vm.prank(USER);
        //         stablecoin.transfer(newUser, 100 ether);
        //         vm.startPrank(newUser);
        //         stablecoin.approve(address(lendingToken), 100 ether);
        //         console.log("Exchange rate before stablecoin deposit:", lendingToken.tokenPrice());
        //         lendingToken.mint(newUser, 100 ether);
        //         console.log("Exchange rate after stablecoin deposit:", lendingToken.tokenPrice());
        //         vm.stopPrank();
        // }
    }

    /*//////////////////////////////////////////////////////////////
                      HELPER FUNCTIONS FOR STABLECOINS
    //////////////////////////////////////////////////////////////*/

    // Helper function to get lending token address based on stablecoin type and lending protocol
    function getLendingTokenAddress(string memory _stablecoinType, uint256 lendingProtocolIndex) internal view returns (address) {
        bool isUSDRIF = keccak256(abi.encodePacked(_stablecoinType)) == keccak256(abi.encodePacked("USDRIF"));
        
        // Check if this stablecoin is supported by Sovryn
        if (lendingProtocolIndex == SOVRYN_INDEX && isUSDRIF) {
            revert("Lending token not available for the selected combination");
        }
        
        address lendingTokenAddress = address(0);
        
        // Try to get the lending token address from the helper configs
        if (isMocSwaps && address(mocHelperConfig) != address(0)) {
            MocHelperConfig.NetworkConfig memory networkConfig = mocHelperConfig.getActiveNetworkConfig();
            
            if (lendingProtocolIndex == TROPYKUS_INDEX) {
                lendingTokenAddress = networkConfig.kDocAddress;
            } else if (lendingProtocolIndex == SOVRYN_INDEX) {
                lendingTokenAddress = networkConfig.iSusdAddress;
            }
        } else if (isDexSwaps && address(dexHelperConfig) != address(0)) {
            if (lendingProtocolIndex == TROPYKUS_INDEX || lendingProtocolIndex == SOVRYN_INDEX) {
                lendingTokenAddress = dexHelperConfig.getLendingTokenAddress();
            }
        }
        
        // If we couldn't get the lending token address from the helper configs, try to get it from the handler
        if (lendingTokenAddress == address(0) && address(docHandler) != address(0)) {
            if (lendingProtocolIndex == TROPYKUS_INDEX) {
                try TropykusDocHandlerMoc(payable(address(docHandler))).i_kToken() returns (IkToken kToken) {
                    lendingTokenAddress = address(kToken);
                } catch {
                    revert("Failed to get Tropykus lending token from handler");
                }
            } else if (lendingProtocolIndex == SOVRYN_INDEX) {
                try SovrynDocHandlerMoc(payable(address(docHandler))).i_iSusdToken() returns (IiSusdToken iSusdToken) {
                    lendingTokenAddress = address(iSusdToken);
                } catch {
                    revert("Failed to get Sovryn lending token from handler");
                }
            }
        }
        
        // If we still couldn't get the lending token address, revert
        if (lendingTokenAddress == address(0)) {
            revert("Lending token not available for the selected combination");
        }
        
        return lendingTokenAddress;
    }
}
