// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Raffle
 * @author Abhivansh Saini
 * @notice Defines the working of a lottery system
 */

contract Raffle {
    error sendMoreEthtoEnterRaffle();
    uint256 private entranceFee;

    event raffleentered(address);

    constructor(uint256 fee) {
        entranceFee = fee;
    }

    function enterRaffle() public payable {
        if (msg.value < entranceFee) {
            revert sendMoreEthtoEnterRaffle();
        }
        emit raffleentered(msg.sender);
    }

    function selectWinner() public {}

    function getEntranceFee() public view returns (uint256) {
        return entranceFee;
    }
}
