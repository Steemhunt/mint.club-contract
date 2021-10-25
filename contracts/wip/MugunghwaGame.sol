// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../lib/IUniswapV2Router02.sol";

/**
* @title Mugunghwa Game - Motivated by Squid Game movie
*
* < Rules >
* 1. Users can join the game with 1 DOGG token (90% goes to prize pool, 10% burned)
* 2. Users can move forward by 1 square on each transaction (randomly kills one player)
* 3. Users who successfully moved 10 squares win the prize
* 4. Sponsors can put additional prize pool
*/
contract MugunghwaGame is Ownable, Pausable {
    IERC20 private baseToken;

    uint256 public burnRate = 1000; // 1,000 / 10,000 = 10% of total prize will be burned on each game
    uint256 public ticketPrice = 1e18; // 1 DOGG token for entrance
    uint256 public deathRate = 5000; // Player can kill one player randomly by 50% chances on every move
    uint256 public prizeRate = 5000; // Winner will take 50% of total accumulated rewards

    // Player => progress
    mapping (address => uint8) public progress;
    address[] private players;
    address private lastPlayer;
    uint256 public accStartCount;
    uint256 public accMoveCount;

    event Start(address player);
    event Move(address player, uint8 progress);
    event SendPrize(address player, uint256 prizeAmount);
    event Kill(address player, address by);
    event UpdateConfig(uint256 burnRate, uint256 ticketPrice, uint256 deathRate, uint256 prizeRate);

    constructor(address baseTokenAddress) {
        baseToken = IERC20(baseTokenAddress);
    }

    function updateConfig(
        uint256 _burnRate,
        uint256 _ticketPrice,
        uint256 _deathRate,
        uint256 _prizeRate
    ) external onlyOwner {
        burnRate = _burnRate;
        ticketPrice = _ticketPrice;
        deathRate = _deathRate;
        prizeRate = _prizeRate;

        emit UpdateConfig(burnRate, ticketPrice, deathRate, prizeRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // @notice This is admin function for migrating contract when upgrade is required.
    // This cannot be called once the ownership is renounced.
    function migrate(address to) external onlyOwner whenPaused {
        require(baseToken.transfer(to, baseToken.balanceOf(address(this))), 'MIGRATION_FAILED');
    }

    function start() external whenNotPaused {
        address player = _msgSender();

        require(baseToken.allowance(player, address(this)) >= ticketPrice, 'NOT_ENOUGH_ALLOWANCE');

        uint256 burnFee = ticketPrice * burnRate / 10000;
        baseToken.transferFrom(player, address(this), ticketPrice - burnFee);
        baseToken.transferFrom(player, address(baseToken), burnFee); // Send to the token contract for burning

        progress[player] = 1;
        players.push(player);

        accStartCount++;
        accMoveCount++;
    }

    /**
        @notice Move by one square, and randomly kill one player
    */
    function move() external whenNotPaused returns (uint8) {
        address player = _msgSender();

        require(progress[player] >= 1, 'NOT_STARTED');

        // MARK: - Defence mechanisims for try-and-error attacks
        // NOTE: This won't prevent all edge cases. More notes on _getRandom() function

        // NOTE: This check can be by passed if a contract is in construction.
        require(!Address.isContract(player), 'CONTRACT_NOT_ALLOWED');

        // NOTE: This check can be by passed using a delegated call
        // ref: https://aliazam60.medium.com/who-called-my-contract-71c434edc50
        require(tx.origin == player, 'NOT_ALLOWED');

        // Prevent the same player play consequantly
        require(lastPlayer != player, 'WAITING_FOR_OTHER');
        lastPlayer = player;

        _killRandom();

        // If the player still alive, move by 1 square
        if (progress[player] >= 1) {
            progress[player]++;

            if (progress[player] == 10) {
                progress[player] = 0; // Reset
                _sendPrize(); // Send prize to the player
            }
        }

        accMoveCount++;
        emit Move(player, progress[player]);

        return progress[player];
    }

    function hasStarted() external view returns (bool) {
        return progress[_msgSender()] >= 1;
    }

    function canMove() external view returns (bool) {
        return progress[_msgSender()] >= 1 && lastPlayer != _msgSender();
    }

    function currentPlayerCount() external view returns (uint256) {
        return players.length;
    }

    function getTotalPrize() external view returns (uint256) {
        return baseToken.balanceOf(address(this));
    }

    function getNextPrize() public view returns (uint256) {
        return baseToken.balanceOf(address(this)) * prizeRate / 10000;
    }

    function _sendPrize() private {
        address player = _msgSender();
        uint256 amount = getNextPrize();

        require(baseToken.transfer(player, amount), 'PRIZE_TRANSFER_FAILED');

        emit SendPrize(player, amount);
    }

    function _killRandom() private {
        if (_getRandom(10000) < deathRate) {
            // Pick a random player
            uint256 playerId = _getRandom(players.length);
            address killedAddress = players[playerId];

            // Remove a player, no order
            players[playerId] = players[players.length - 1];
            players.pop();
            progress[killedAddress] = 0;

            emit Kill(killedAddress, _msgSender());
        }
    }

    /**
     * @dev get a pseudo random number within the range
     *
     * NOTE: This is not a real random number, and anyone can check what this function generates.
     * This means players can see who they will kill on their `move()` transaction
     *
     * Two benefits by hack this contract:
     *  1. Users can avoid kill him/her self
     *  2. Users can use multiple accounts to make their main account go forward with less risks.
     *
     * We can solve this issue by using VRF, or an external oracle (a.k.a centralization),
     * but that becomes too complicated and cost inefficient for this small event project.
     * I will leave these edge cases as a part of playing tactic.
     */
    function _getRandom(uint256 range) private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_msgSender(), block.number, block.timestamp, accMoveCount))) % range;
    }
}
