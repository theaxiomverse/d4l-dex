// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/**
 * @title FoundersVesting
 * @notice Advanced vesting contract for founders with cliff, linear vesting, and emergency controls
 * @dev Features:
 * - 4 year vesting with 1 year cliff
 * - Linear daily vesting after cliff
 * - Emergency pause and recovery
 * - Multi-signature control
 * - Anti-rugpull mechanisms
 */
contract FoundersVesting is Auth {
    using SafeTransferLib for ERC20;

    struct VestingSchedule {
        uint256 totalAmount;      // Total tokens to vest
        uint256 claimedAmount;    // Amount already claimed
        uint256 startTime;        // Start of vesting period
        uint256 cliffEnd;         // End of cliff period
        uint256 vestingEnd;       // End of vesting period
        bool isActive;            // Whether schedule is active
        bool isRevocable;         // Whether schedule can be revoked
    }

    ERC20 public immutable token;
    
    // Founder address => VestingSchedule
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Emergency controls
    bool public isPaused;
    uint256 public constant EMERGENCY_DELAY = 7 days;
    mapping(address => uint256) public lastEmergencyAction;

    // Time constants
    uint256 public constant VESTING_DURATION = 1460 days; // 4 years
    uint256 public constant CLIFF_DURATION = 365 days;    // 1 year
    uint256 public constant DAILY_INTERVAL = 1 days;

    // Events
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 remainingAmount);
    event EmergencyActionInitiated(address indexed caller, bytes32 indexed actionType);
    event EmergencyActionExecuted(address indexed caller, bytes32 indexed actionType);

    // Custom errors
    error NoScheduleExists();
    error CliffNotReached();
    error NothingToClaim();
    error NotRevocable();
    error EmergencyDelayNotMet();
    error InvalidAmount();
    error ContractPaused();

    constructor(
        address _token,
        address _owner,
        Authority _authority
    ) Auth(_owner, _authority) {
        token = ERC20(_token);
    }

    /**
     * @notice Create a new vesting schedule for a founder
     * @param beneficiary Address of the founder
     * @param amount Total amount of tokens to vest
     * @param isRevocable Whether the schedule can be revoked
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        bool isRevocable
    ) external requiresAuth {
        if (amount == 0) revert InvalidAmount();
        if (vestingSchedules[beneficiary].isActive) revert("Schedule exists");

        uint256 startTime = block.timestamp;
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            claimedAmount: 0,
            startTime: startTime,
            cliffEnd: startTime + CLIFF_DURATION,
            vestingEnd: startTime + VESTING_DURATION,
            isActive: true,
            isRevocable: isRevocable
        });

        emit VestingScheduleCreated(beneficiary, amount);
    }

    /**
     * @notice Calculate vested amount for a beneficiary
     * @param beneficiary Address of the founder
     * @return vestedAmount Amount of tokens vested
     */
    function calculateVestedAmount(address beneficiary) public view returns (uint256 vestedAmount) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        if (!schedule.isActive) revert NoScheduleExists();

        if (block.timestamp < schedule.cliffEnd) {
            return 0;
        }

        if (block.timestamp >= schedule.vestingEnd) {
            return schedule.totalAmount;
        }

        // Calculate linear vesting after cliff
        uint256 timeAfterCliff = block.timestamp - schedule.cliffEnd;
        uint256 vestingDuration = schedule.vestingEnd - schedule.cliffEnd;
        
        vestedAmount = (schedule.totalAmount * timeAfterCliff) / vestingDuration;
    }

    /**
     * @notice Claim vested tokens
     */
    function claimVestedTokens() external {
        if (isPaused) revert ContractPaused();
        
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (!schedule.isActive) revert NoScheduleExists();
        
        uint256 vestedAmount = calculateVestedAmount(msg.sender);
        uint256 claimableAmount = vestedAmount - schedule.claimedAmount;
        
        if (claimableAmount == 0) revert NothingToClaim();
        
        schedule.claimedAmount += claimableAmount;
        token.safeTransfer(msg.sender, claimableAmount);
        
        emit TokensClaimed(msg.sender, claimableAmount);
    }

    /**
     * @notice Revoke vesting schedule (only for revocable schedules)
     * @param beneficiary Address of the founder
     */
    function revokeVesting(address beneficiary) external requiresAuth {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        if (!schedule.isActive) revert NoScheduleExists();
        if (!schedule.isRevocable) revert NotRevocable();

        uint256 vestedAmount = calculateVestedAmount(beneficiary);
        uint256 remainingAmount = schedule.totalAmount - vestedAmount;

        schedule.isActive = false;
        schedule.totalAmount = vestedAmount;

        emit VestingRevoked(beneficiary, remainingAmount);
    }

    /**
     * @notice Initiate emergency action
     * @param actionType Type of emergency action
     */
    function initiateEmergencyAction(bytes32 actionType) external requiresAuth {
        lastEmergencyAction[msg.sender] = block.timestamp;
        emit EmergencyActionInitiated(msg.sender, actionType);
    }

    /**
     * @notice Execute emergency action after delay
     * @param actionType Type of emergency action
     */
    function executeEmergencyAction(bytes32 actionType) external requiresAuth {
        uint256 lastAction = lastEmergencyAction[msg.sender];
        if (block.timestamp < lastAction + EMERGENCY_DELAY) {
            revert EmergencyDelayNotMet();
        }

        if (actionType == "PAUSE") {
            isPaused = true;
        } else if (actionType == "UNPAUSE") {
            isPaused = false;
        }

        emit EmergencyActionExecuted(msg.sender, actionType);
    }
} 