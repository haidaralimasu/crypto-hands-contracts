// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
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

    address private s_cryptoHandsAddress;

    uint256 private s_maxBet;
    uint256 private s_minBet;
    uint256 private s_divider = 100;

    Counters.Counter private s_betId;

    mapping(uint256 => Bet) public s_bets;
    mapping(address => uint256) public s_nftWinPercentage;
    mapping(address => uint256) public s_gamesPlayed;
    mapping(address => uint256) public s_gamesWon;
    mapping(address => uint256) public s_nftWon;

    constructor(
        uint256 _maxBet,
        uint256 _minBet,
        address _cryptoHands
    ) {
        s_maxBet = _maxBet;
        s_minBet = _minBet;
        s_cryptoHands = ICryptoHands(_cryptoHands);
        s_cryptoHandsAddress = _cryptoHands;
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
            }
            if (s_nftWinPercentage[msg.sender] > _randomNumber) {
                s_cryptoHands.winHands(msg.sender);
            }
        }

        _createBetAndSettle(_choice, msg.sender, msg.value);

        s_nftWinPercentage[msg.sender] = s_nftWinPercentage[msg.sender] + 1;
    }

    function claim() external nonReentrant whenNotPaused {
        uint256 totalSupply = IERC721A(s_cryptoHandsAddress).totalSupply();
        uint256 nftBalance = IERC721A(s_cryptoHandsAddress).balanceOf(
            msg.sender
        );
        require(nftBalance >= 1, "You must own 1 NFT");

        uint256 contractBalance = address(this).balance;
        uint256 claimableAmount = contractBalance / totalSupply;

        uint256 userClaimableAmount = claimableAmount * nftBalance;

        (bool os, ) = payable(owner()).call{value: userClaimableAmount}("");
        require(os, "Failed to Claim");
    }

    function _createBetAndSettle(
        uint256 _choice,
        address _player,
        uint256 _betAmount
    ) internal {
        GameChoices _playerChoice = _getChoiceAccordingToNumber(_choice);

        GameChoices _outcome = _getRockOrPaperOrScissors(_player);

        uint256 winAmount = _amountToWinningPool(msg.value);

        Results _result = _winOrLoose(_playerChoice, _outcome);

        if (_result == Results.Win) {
            (bool hs, ) = payable(_player).call{value: winAmount}("");
            require(hs, "Failed to send MATIC 1");

            s_gamesWon[_player] = s_gamesWon[_player] + 1;
            s_nftWon[_player] = s_nftWon[_player] + 1;
        }
        if (_result == Results.Tie) {
            (bool hs, ) = payable(_player).call{value: _betAmount}("");
            require(hs, "Failed to send MATIC 2");
        }

        Bet memory _bet = Bet(
            s_betId.current(),
            _playerChoice,
            _outcome,
            _player,
            msg.value,
            winAmount,
            _result
        );

        s_bets[s_betId.current()] = _bet;
        s_betId.increment();

        emit BetCreated(
            s_betId.current(),
            _playerChoice,
            _player,
            _betAmount,
            winAmount,
            _getCurrentTime()
        );

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

        s_gamesPlayed[_player] = s_gamesPlayed[_player] + 1;
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
        _winningPool = (balance / s_divider) + _bet;
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
                    _getCurrentTime(),
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
        require(_number < 3, "RockPaperScissors: Choice should be less than 3");
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

    function _getRockOrPaperOrScissors(address _sender)
        internal
        view
        returns (GameChoices _outcome)
    {
        uint256 randomNumber = _getRandomNumber(s_betId.current(), _sender);
        uint256 randomOutcome = randomNumber % 3;

        _outcome = _getChoiceAccordingToNumber(randomOutcome);
    }

    function _getCurrentTime() internal view returns (uint256 _currentTime) {
        _currentTime = block.timestamp;
    }

    function getGameAddress()
        internal
        view
        returns (ICryptoHands _gameAddress)
    {
        _gameAddress = s_cryptoHands;
    }

    function getMaxBet() external view returns (uint256 _maxBet) {
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
        s_cryptoHandsAddress = _cryptoHands;
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

    function withdraw(uint256 _amount) external onlyOwner {
        (bool os, ) = payable(owner()).call{value: _amount}("");
        require(os);
    }
}
