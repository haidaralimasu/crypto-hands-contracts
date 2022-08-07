// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IRockPaperScissors {
    struct Bet {
        GameChoices choice;
        GameChoices outcome;
        address player;
        uint256 amount;
        uint128 winAmount;
        bool isSettled;
    }

    enum GameChoices {
        Rock,
        Paper,
        Scissors
    }

    event CryptoHandsUpdated(address _newCryptoHands);
    event MaxBetUpdated(uint256 _newMaxBet);
    event MinBetUpdated(uint256 _newMinBet);
}
