// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/deployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract raffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    /* Events declaration */
    event EnteredRaffle(address indexed player);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) =
            helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* enterRaffle functions */

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
    }

    function testEventEmitOnEntry() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false);
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
}
