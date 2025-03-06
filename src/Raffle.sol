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
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Raffle
 * @author Abhivansh Saini
 * @notice Defines the working of a lottery system
 */

contract Raffle is VRFConsumerBaseV2Plus {
    error sendMoreEthtoEnterRaffle();
    error notEnoughTimePassed();
    error TransferToWinnerFailed();
    error RaffleClosed();
    error upKeepNotNeeded(uint256 timePassed, uint256 raffleState, uint256 balance, uint256 players);

    enum RaffleState {
        OPEN, //0
        CALCULATING_WINNER //1
    }

    uint256 private i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private lastTimeStamp;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    address private recentWinner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event WinnerFound(address indexed winner);

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane,
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (s_raffleState == RaffleState.CALCULATING_WINNER) {
            revert RaffleClosed();
        }
        if (msg.value < i_entranceFee) {
            revert sendMoreEthtoEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function chechUpKeep(bytes memory /* checkData */) public view returns (bool upKeepNeeded, bytes memory performData) {
        bool timeHasPassed = block.timestamp - lastTimeStamp >= i_interval;
        bool raffleOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = !timeHasPassed && raffleOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "");
    }

    function performUpKeep() external {
        (bool upKeepNedded, ) = chechUpKeep("");
        if (upKeepNedded) {
            revert upKeepNotNeeded(block.timestamp - lastTimeStamp, uint256(s_raffleState), address(this).balance, s_players.length);
        }
        s_raffleState = RaffleState.CALCULATING_WINNER;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 winnerIndex = uint256(randomWords[0]) % s_players.length;
        address winner = s_players[winnerIndex];
        recentWinner = winner;
        emit WinnerFound(winner);
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert TransferToWinnerFailed();
        }
        delete s_players;
        lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }
}
