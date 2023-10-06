// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A raffle contract
 * @author Zacarias Bouciguez
 * @notice This contract is for the creation of a raffle and the management of the raffle
 */

contract Raffle is VRFConsumerBaseV2 {
    //*Errors */
    error Raffle__notEnoughEthToEnterRaffle();
    error Raffle__transferFailed();
    error Raffle__calculatingAWinner();
    error Raffle__upkeepNotNeeded(
        uint256 balance, uint256 raffleState, uint256 playersLength, uint256 timeSinceLastPick
    );

    //*Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * Constants
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**
     * State Variables
     */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    RaffleState private s_raffleState;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;

    //* Events */
    event PickedWinner(address indexed winner);
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__notEnoughEthToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__calculatingAWinner();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepNotNeeded(
                address(this).balance, uint256(s_raffleState), s_players.length, block.timestamp - s_lastTimeStamp
            );
        }
        s_raffleState = RaffleState.CALCULATING;

        // Get the random number -> pick the wallet based on the random number
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transferFailed();
        }
        s_raffleState = RaffleState.OPEN;
        emit PickedWinner(winner);
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }
}
