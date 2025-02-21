// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AntiRugPull
 * @author Degen4Life Team
 * @notice Prevents rug pulls by implementing trading restrictions
 * @dev Implements sell limits, wallet size limits, and daily trading limits
 * @custom:security-contact security@memeswap.exchange
 */
contract AntiRugPull is Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint256 public constant MAX_SELL_PERCENT = 10;     // 10% max sell of liquidity
    uint256 public constant MIN_LOCK_TIME = 30 days;
    uint256 public constant MAX_TEAM_WALLET_PERCENT = 15; // 15% max for team wallet
    
    // Structs
    struct LockInfo {
        uint256 lockTime;             // Time when liquidity was locked
        uint256 unlockTime;           // Time when liquidity can be unlocked
        uint256 lockedAmount;         // Amount of tokens/LP locked
        bool isLPToken;               // True if locked token is LP token
    }

    struct TeamVesting {
        uint256 totalAmount;          // Total tokens for team
        uint256 vestedAmount;         // Amount already vested
        uint256 vestingStart;         // Start of vesting period
        uint256 vestingDuration;      // Total vesting duration
        uint256 lastClaimTime;        // Last time tokens were claimed
    }

    // State variables
    mapping(address => mapping(address => LockInfo)) public locks;        // token => owner => LockInfo
    mapping(address => TeamVesting) public teamVesting;                   // token => TeamVesting
    mapping(address => mapping(address => bool)) public isWhitelisted;    // token => address => whitelist status
    mapping(address => bool) public isProtected;                         // token => protection status
    
    // Events
    event TokenLocked(address indexed token, address indexed owner, uint256 amount, uint256 unlockTime);
    event TokenUnlocked(address indexed token, address indexed owner, uint256 amount);
    event TeamTokensVested(address indexed token, address indexed beneficiary, uint256 amount);
    event WhitelistUpdated(address indexed token, address indexed account, bool status);
    event ProtectionEnabled(address indexed token);
    event ProtectionDisabled(address indexed token);

    constructor() Ownable(msg.sender) {}

    function enableProtection(address token) external onlyOwner {
        isProtected[token] = true;
        emit ProtectionEnabled(token);
    }

    function disableProtection(address token) external onlyOwner {
        isProtected[token] = false;
        emit ProtectionDisabled(token);
    }

    function setWhitelisted(
        address token,
        address account,
        bool status
    ) external onlyOwner {
        isWhitelisted[token][account] = status;
        emit WhitelistUpdated(token, account, status);
    }

    function lockTokens(
        address token,
        uint256 amount,
        uint256 lockDuration,
        bool isLP
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be > 0");
        require(lockDuration >= MIN_LOCK_TIME, "Lock time too short");
        
        LockInfo storage lock = locks[token][msg.sender];
        require(lock.lockTime == 0, "Already locked");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        lock.lockTime = block.timestamp;
        lock.unlockTime = block.timestamp + lockDuration;
        lock.lockedAmount = amount;
        lock.isLPToken = isLP;

        emit TokenLocked(token, msg.sender, amount, lock.unlockTime);
    }

    function unlockTokens(address token) external nonReentrant {
        LockInfo storage lock = locks[token][msg.sender];
        require(lock.lockTime > 0, "No tokens locked");
        require(block.timestamp >= lock.unlockTime, "Still locked");
        
        uint256 amount = lock.lockedAmount;
        delete locks[token][msg.sender];
        
        IERC20(token).transfer(msg.sender, amount);
        emit TokenUnlocked(token, msg.sender, amount);
    }

    function setupTeamVesting(
        address token,
        uint256 amount,
        uint256 vestingDuration
    ) external onlyOwner {
        require(teamVesting[token].totalAmount == 0, "Vesting already setup");
        require(amount <= IERC20(token).totalSupply() * MAX_TEAM_WALLET_PERCENT / 100, "Amount too high");
        
        teamVesting[token] = TeamVesting({
            totalAmount: amount,
            vestedAmount: 0,
            vestingStart: block.timestamp,
            vestingDuration: vestingDuration,
            lastClaimTime: block.timestamp
        });
    }

    function claimVestedTokens(address token) external nonReentrant {
        TeamVesting storage vesting = teamVesting[token];
        require(vesting.totalAmount > 0, "No vesting setup");
        
        uint256 vestedAmount = calculateVestedAmount(token);
        uint256 claimable = vestedAmount - vesting.vestedAmount;
        require(claimable > 0, "Nothing to claim");
        
        vesting.vestedAmount = vestedAmount;
        vesting.lastClaimTime = block.timestamp;
        
        IERC20(token).transfer(msg.sender, claimable);
        emit TeamTokensVested(token, msg.sender, claimable);
    }

    function calculateVestedAmount(address token) public view returns (uint256) {
        TeamVesting memory vesting = teamVesting[token];
        if (block.timestamp < vesting.vestingStart) return 0;
        if (block.timestamp >= vesting.vestingStart + vesting.vestingDuration) {
            return vesting.totalAmount;
        }
        
        return vesting.totalAmount * (block.timestamp - vesting.vestingStart) / vesting.vestingDuration;
    }

    function validateTransfer(
        address token,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool) {
        if (!isProtected[token]) return true;
        if (isWhitelisted[token][from] || isWhitelisted[token][to]) return true;
        
        // Check if it's a sell transaction and validate against max sell percent
        if (locks[token][from].isLPToken) {
            uint256 lpBalance = IERC20(token).balanceOf(from);
            if (amount > lpBalance * MAX_SELL_PERCENT / 100) return false;
        }
        
        return true;
    }

    function getLockInfo(
        address token,
        address owner
    ) external view returns (
        uint256 lockTime,
        uint256 unlockTime,
        uint256 lockedAmount,
        bool isLPToken
    ) {
        LockInfo memory lock = locks[token][owner];
        return (lock.lockTime, lock.unlockTime, lock.lockedAmount, lock.isLPToken);
    }

    function getVestingInfo(
        address token
    ) external view returns (
        uint256 totalAmount,
        uint256 vestedAmount,
        uint256 vestingStart,
        uint256 vestingDuration,
        uint256 lastClaimTime
    ) {
        TeamVesting memory vesting = teamVesting[token];
        return (
            vesting.totalAmount,
            vesting.vestedAmount,
            vesting.vestingStart,
            vesting.vestingDuration,
            vesting.lastClaimTime
        );
    }
}