// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/deployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";

contract deployRaffleTest is Test {
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;
    HelperConfig helperConfig;

    function setUp() external {
        helperConfig = new HelperConfig();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, linkAddress,) =
            helperConfig.activeNetworkConfig();
    }

    function testDeployRaffle() public {
        DeployRaffle deployer = new DeployRaffle();
        (Raffle raffle,) = deployer.run();
        assert(entranceFee == raffle.getEntranceFee());
        assert(interval == raffle.getInterval());
        //assert(vrfCoordinator == raffle.getVrfcoordinator());
        assert(gasLane == raffle.getGasLane());
        //assert(subscriptionId == raffle.getSubscriptionId());
        assert(callbackGasLimit == raffle.getCallbackGasLimit());
        //assert(linkAddress == raffle.getLinkAddress());
        //assert(helperConfig == helperConfig2);
    }
}
