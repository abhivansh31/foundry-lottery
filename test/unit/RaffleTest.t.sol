//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    DeployRaffle deployRaffle;

    uint256 private subscriptionId;
    bytes32 private gasLane;
    uint256 private interval;
    uint256 private entranceFee;
    uint32 private callbackGasLimit;
    address private vrfCoordinatorV2;

    address user = makeAddr("0x123");
    uint256 private startingBalance = 10 ether;

    event EnteredRaffle(address indexed player);
    event WinnerFound(address indexed winner);

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deploy();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        subscriptionId = config.subscriptionId;
        gasLane = config.gasLane;
        interval = config.interval;
        entranceFee = config.entranceFee;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinatorV2 = config.vrfCoordinatorV2; 

    }
    function testOpeningState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEntranceFee() public view {
        assert(raffle.getEntranceFee() == entranceFee);
    }

    function testEntry() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers(0) == user);
    }

    function testEntrance() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        vm.expectRevert(Raffle.sendMoreEthtoEnterRaffle.selector);
        raffle.enterRaffle{value: entranceFee-1}();
    }

    function testEnterRaffleEvent() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(user);
        raffle.enterRaffle{value: entranceFee}();

    }

    function testDontALlowPlayersToAllowWhileRaffleIsCalculating() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep();
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER);
        vm.expectRevert(Raffle.RaffleClosed.selector);
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
        
    }
}
