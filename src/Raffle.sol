// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Raffle
 * @author Abhivansh Saini
 * @notice Defines the working of a lottery system
 */

contract Raffle {
    error sendMoreEthtoEnterRaffle();
    error notEnoughTimePassed();

    uint256 private i_entranceFee;
    address payable[] private s_players;
    uint256 private immutable i_interval;
    uint256 private lastTimeStamp;

    event raffleentered(address indexed player);

    constructor(uint256 _fee, uint256 _interval) {
        i_entranceFee = _fee;
        i_interval = _interval;
        lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert sendMoreEthtoEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit raffleentered(msg.sender); 
    }

    function selectWinner() public view {
        if (block.timestamp - lastTimeStamp < i_interval) {
            revert notEnoughTimePassed();
        }
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
