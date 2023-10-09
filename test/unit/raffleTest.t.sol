// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/deployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract raffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* Events declaration */
    event EnteredRaffle(address indexed player);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkAddress
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* enterRaffle tests */

    function testRaffleRevertsIfNotEnoughMoney() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__notEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleSavesPlayerOnEntry() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(PLAYER == raffle.getPlayer(0));
    }

    function testCannotEnterRaffleIsCalculatingWinner() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__calculatingAWinner.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testEventEmitOnEntry() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false);
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* checkUpkeep tests */
    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool answer, ) = raffle.checkUpkeep("");
        assert(!answer);
    }

    function testCheckUpkeepReturnsFalseIfNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool answer, ) = raffle.checkUpkeep("");
        assert(!answer);
    }

    function testCheckUpkeepReturnsFalseIfTimeNotPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        (bool answer, ) = raffle.checkUpkeep("");
        assert(!answer);
    }

    function testCheckUpkeepReturnsTrueIfEverythingIsOkay() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool answer, ) = raffle.checkUpkeep("");
        assert(answer);
    }

    /* performUpkeep tests */

    function testPerformUpkeepFailsIfCheckUpKeepIsFalse() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upkeepNotNeeded.selector,
                address(raffle).balance,
                raffle.getRaffleState(),
                raffle.getNumPlayers(),
                0
            )
        );
        vm.prank(PLAYER);
        raffle.performUpkeep("");
    }

    function testPerformUpkeepSucceedsIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.prank(PLAYER);
        raffle.performUpkeep("");
        bool result = raffle.getRaffleState() == Raffle.RaffleState.CALCULATING;
        assert(result);
    }

    /* fullfillRandomWords tests */
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testFullfillRandomWordsRevertsIfCallFails(
        uint256 randomRequestId
    ) public raffleEntered {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        uint256 additionalEntrances = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner != address(0));
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == STARTING_USER_BALANCE + prize - entranceFee);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
