//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


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
    event LogRequestId(uint256 requestId);

    modifier raffleEntered() {
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

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

    function testEntry() public raffleEntered {
        assert(raffle.getPlayers(0) == user);
    }

    function testEntrance() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        vm.expectRevert(Raffle.sendMoreEthtoEnterRaffle.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testEnterRaffleEvent() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(user);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToAllowWhileRaffleIsCalculating() public raffleEntered {
        raffle.performUpKeep();
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
        vm.expectRevert(Raffle.RaffleClosed.selector);
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersWithNoBalance() public {
        vm.prank(user);
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assertEq(upKeepNeeded, false);
    }

    function testDontAllowPlayersIfTheRaffleIsCalculating() public raffleEntered {
        raffle.performUpKeep();
        (bool upKeepNeeded, ) = raffle.checkUpKeep("");
        assertEq(upKeepNeeded, false);
    }

    function testPerformUpKeepShouldNotRunIfCheckUpKeepIsFalse() public {
        vm.prank(user);
        vm.deal(user, startingBalance);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        vm.expectRevert();
        raffle.performUpKeep();
    }

    function testPerformUpKeepEventsLog() public raffleEntered {
        vm.recordLogs();
        raffle.performUpKeep();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[0].topics[1];
        assert(
            raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER
        );
        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsCanOnlyRunAfterPerformKeepUp(uint256 randomRequestId) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2).fulfillRandomWords(randomRequestId, address(raffle));
    }

}