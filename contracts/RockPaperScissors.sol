// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ICryptoHands} from "./interfaces/ICryptoHands.sol";
import {IRockPaperScissors} from "./interfaces/IRockPaperScissors.sol";

contract StonePaperScissors is
    Pausable,
    ReentrancyGuard,
    Ownable,
    IRockPaperScissors
{
    using Counters for Counters.Counter;

    ICryptoHands private s_cryptoHands;

    uint256 private s_maxBet;
    uint256 private s_minBet;

    Counters.Counter private s_betId;

    mapping(uint256 => Bet) public s_bets;

    constructor(
        uint256 _maxBet,
        uint256 _minBet,
        address _cryptoHands
    ) {
        s_maxBet = _maxBet;
        s_minBet = _minBet;
        s_cryptoHands = ICryptoHands(_cryptoHands);
    }

    function _getRandomNumber(uint256 _num, address _sender)
        internal
        view
        returns (uint256 _randomNumber)
    {
        _randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    s_betId.current(),
                    _getBlockDifficulty(),
                    _getCurrentTime(),
                    _getBlockNumber(),
                    _sender,
                    _num
                )
            )
        );
    }

    function _getRockOrPaperOrScissors(uint256 _num, address _sender)
        internal
        view
        returns (GameChoices _outcome)
    {
        uint256 randomNumber = _getRandomNumber(_num, _sender);
        uint256 randomOutcome = randomNumber % 3;

        if (randomOutcome == 0) {
            _outcome = GameChoices.Rock;
        }
        if (randomOutcome == 1) {
            _outcome = GameChoices.Paper;
        }
        if (randomNumber == 2) {
            _outcome = GameChoices.Scissors;
        }
    }

    function _getBlockDifficulty()
        internal
        view
        returns (uint256 _blockDifficulty)
    {
        _blockDifficulty = block.difficulty;
    }

    function _getCurrentTime() internal view returns (uint256 _currentTime) {
        _currentTime = block.timestamp;
    }

    function _getBlockNumber() internal view returns (uint256 _blockNumber) {
        _blockNumber = block.number;
    }

    function _getMaxBet() external view returns (uint256 _maxBet) {
        _maxBet = s_maxBet;
    }

    function getMinBet() external view returns (uint256 _minBet) {
        _minBet = s_minBet;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateCryptoHands(address _cryptoHands) external onlyOwner {
        s_cryptoHands = ICryptoHands(_cryptoHands);
        emit CryptoHandsUpdated(_cryptoHands);
    }

    function updateMaxBet(uint256 _maxBet) external onlyOwner {
        s_maxBet = _maxBet;
        emit MaxBetUpdated(_maxBet);
    }

    function updateMinBet(uint256 _minBet) external onlyOwner {
        s_minBet = _minBet;
        emit MinBetUpdated(_minBet);
    }
}
