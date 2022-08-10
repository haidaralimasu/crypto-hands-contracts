// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ICryptoHands} from "./interfaces/ICryptoHands.sol";
import {IRockPaperScissors} from "./interfaces/IRockPaperScissors.sol";

contract RockPaperScissors is
    Pausable,
    ReentrancyGuard,
    Ownable,
    IRockPaperScissors
{
    using Counters for Counters.Counter;

    ICryptoHands private s_cryptoHands;

    uint256 private s_maxBet;
    uint256 private s_minBet;
    uint256 private s_divider;

    Counters.Counter private s_betId;

    mapping(uint256 => Bet) public s_bets;
    mapping(address => uint256) public s_nftWinPercentage;

    constructor(
        uint256 _maxBet,
        uint256 _minBet,
        address _cryptoHands
    ) {
        s_maxBet = _maxBet;
        s_minBet = _minBet;
        s_cryptoHands = ICryptoHands(_cryptoHands);
    }

    function makeBet(uint256 _choice)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(
            msg.value >= s_minBet,
            "RockPaperScissors: Bet is Smaller than Minimum Bet Amount"
        );
        require(
            msg.value <= s_maxBet,
            "RockPaperScissors: Bet is Greater than Maximun Bet Amount"
        );
        require(_choice < 3, "RoclPaperScissors: Choice Shoule Be 0, 1 or 2");
        uint256 _randomNumber = _getRandomNumber(
            s_betId.current(),
            msg.sender
        ) % 10000;

        uint256 totalHandsWinned = s_cryptoHands.getTotalHandsWinned();
        uint256 maxHandsAvailableToWin = s_cryptoHands
            .getMaxHandsAvailableToWin();

        if (totalHandsWinned <= maxHandsAvailableToWin) {
            if (s_nftWinPercentage[msg.sender] == 10000) {
                s_cryptoHands.winHands(msg.sender);
                s_nftWinPercentage[msg.sender] == 0;
            } else if (s_nftWinPercentage[msg.sender] > _randomNumber) {
                s_cryptoHands.winHands(msg.sender);
            }
        }

        _createBetAndSettle(_choice, msg.sender);

        s_nftWinPercentage[msg.sender] = s_nftWinPercentage[msg.sender] + 1;
    }

    function _createBetAndSettle(uint256 _choice, address _player) internal {
        GameChoices _playerChoice = _getChoiceAccordingToNumber(_choice);
        GameChoices _outcome = _getRockOrPaperOrScissors(
            s_betId.current(),
            _player
        );
        uint256 winAmount = _amountToWinningPool(msg.value);

        emit BetCreated(
            s_betId.current(),
            _playerChoice,
            _player,
            msg.value,
            winAmount,
            _getCurrentTime()
        );

        Results _result = _winOrLoose(_playerChoice, _outcome);

        if (_result == Results.Win) {
            (bool hs, ) = payable(_player).call{value: winAmount}("");
            require(hs);
        }
        if (_result == Results.Tie) {
            (bool hs, ) = payable(_player).call{value: msg.value}("");
            require(hs);
        }
        if (_result == Results.Loose) {
            (bool hs, ) = payable(address(this)).call{value: msg.value}("");
            require(hs);
        }

        Bet memory _bet = Bet({
            betId: s_betId.current(),
            choice: _playerChoice,
            outcome: _outcome,
            player: _player,
            amount: msg.value,
            winAmount: winAmount,
            result: _result
        });

        s_bets[s_betId.current()] = _bet;
        s_betId.increment();

        emit ResultsDeclared(
            _bet.betId,
            _bet.choice,
            _bet.outcome,
            _bet.amount,
            _bet.winAmount,
            _bet.player,
            _bet.result,
            _getCurrentTime()
        );
    }

    function _winOrLoose(GameChoices _playerChoice, GameChoices _outcome)
        internal
        pure
        returns (Results _result)
    {
        if (_playerChoice == GameChoices.Rock && _outcome == GameChoices.Rock) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Rock && _outcome == GameChoices.Paper
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Rock &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Win;
        }
        if (
            _playerChoice == GameChoices.Paper && _outcome == GameChoices.Paper
        ) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Paper &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Paper && _outcome == GameChoices.Rock
        ) {
            _result = Results.Win;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Scissors
        ) {
            _result = Results.Tie;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Rock
        ) {
            _result = Results.Loose;
        }
        if (
            _playerChoice == GameChoices.Scissors &&
            _outcome == GameChoices.Paper
        ) {
            _result = Results.Win;
        }
    }

    function _amountToWinningPool(uint256 _bet)
        internal
        view
        returns (uint256 _winningPool)
    {
        uint256 balance = address(this).balance;
        _winningPool = _bet + balance / s_divider;
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

    function _getChoiceAccordingToNumber(uint256 _number)
        internal
        pure
        returns (GameChoices _gameChoice)
    {
        if (_number == 0) {
            _gameChoice = GameChoices.Rock;
        }
        if (_number == 1) {
            _gameChoice = GameChoices.Paper;
        }
        if (_number == 2) {
            _gameChoice = GameChoices.Scissors;
        }
    }

    function _getRockOrPaperOrScissors(uint256 _num, address _sender)
        internal
        view
        returns (GameChoices _outcome)
    {
        uint256 randomNumber = _getRandomNumber(_num, _sender);
        uint256 randomOutcome = randomNumber % 3;

        _outcome = _getChoiceAccordingToNumber(randomOutcome);
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

    function updateDivider(uint256 _divider) external onlyOwner {
        s_divider = _divider;
        emit DividerUpdated(_divider);
    }

    function deposite() external payable nonReentrant {}
}
