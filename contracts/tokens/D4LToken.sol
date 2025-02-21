// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../interfaces/IContractRegistry.sol";
import "../interfaces/ITokenomics.sol";

/**
 * @title D4LToken
 * @notice Native token of the Degen4Life platform with special features
 * @dev Implements DAO governance and platform-specific tokenomics
 */
contract D4LToken is ERC20VotesUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    // Constants
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;     // Fixed max supply
    uint256 public constant VESTING_DURATION = 365 days;           // 1 year vesting
    uint256 public constant CLIFF_DURATION = 90 days;              // 3 months cliff
    uint256 public constant RELEASE_INTERVAL = 1 days;             // Daily release

    // State variables
    IContractRegistry public registry;
    ITokenomics public tokenomics;
    address public governanceAddress;
    
    // Vesting schedule
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffEnd;
        uint256 endTime;
        uint256 lastClaimTime;
        uint256 claimedAmount;
        bool revocable;
        bool revoked;
    }
    
    // Allocation percentages (in basis points, 100 = 1%)
    uint256 public constant TEAM_ALLOCATION = 1500;        // 15%
    uint256 public constant ADVISORS_ALLOCATION = 500;     // 5%
    uint256 public constant ECOSYSTEM_ALLOCATION = 2000;   // 20%
    uint256 public constant LIQUIDITY_ALLOCATION = 1500;   // 15%
    uint256 public constant COMMUNITY_ALLOCATION = 4500;   // 45%

    // Vesting schedules
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Staking rewards
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingStartTime;
    mapping(address => uint256) public rewardDebt;
    
    // Events
    event TokensVested(address indexed beneficiary, uint256 amount);
    event VestingScheduleCreated(address indexed beneficiary, uint256 amount);
    event VestingScheduleRevoked(address indexed beneficiary);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _registry,
        address _tokenomics,
        address _governanceAddress,
        address teamWallet,
        address advisorsWallet,
        address ecosystemWallet,
        address liquidityWallet,
        address communityWallet
    ) external initializer {
        __ERC20_init("Degen4Life", "D4L");
        __ERC20Votes_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        registry = IContractRegistry(_registry);
        tokenomics = ITokenomics(_tokenomics);
        governanceAddress = _governanceAddress;
        
        // Create initial supply
        _mint(address(this), INITIAL_SUPPLY);
        
        // Create vesting schedules
        _createVestingSchedule(teamWallet, (INITIAL_SUPPLY * TEAM_ALLOCATION) / 10000, true);
        _createVestingSchedule(advisorsWallet, (INITIAL_SUPPLY * ADVISORS_ALLOCATION) / 10000, true);
        _createVestingSchedule(ecosystemWallet, (INITIAL_SUPPLY * ECOSYSTEM_ALLOCATION) / 10000, false);
        
        // Transfer liquidity and community allocations immediately
        _transfer(address(this), liquidityWallet, (INITIAL_SUPPLY * LIQUIDITY_ALLOCATION) / 10000);
        _transfer(address(this), communityWallet, (INITIAL_SUPPLY * COMMUNITY_ALLOCATION) / 10000);
    }

    // Vesting functions
    function _createVestingSchedule(
        address beneficiary,
        uint256 amount,
        bool revocable
    ) internal {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be > 0");
        
        uint256 start = block.timestamp;
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: start,
            cliffEnd: start + CLIFF_DURATION,
            endTime: start + VESTING_DURATION,
            lastClaimTime: start,
            claimedAmount: 0,
            revocable: revocable,
            revoked: false
        });
        
        emit VestingScheduleCreated(beneficiary, amount);
    }
    
    function claimVestedTokens() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Schedule revoked");
        require(block.timestamp > schedule.cliffEnd, "Cliff not ended");
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        require(vestedAmount > schedule.claimedAmount, "No tokens to claim");
        
        uint256 claimableAmount = vestedAmount - schedule.claimedAmount;
        schedule.claimedAmount = vestedAmount;
        schedule.lastClaimTime = block.timestamp;
        
        _transfer(address(this), msg.sender, claimableAmount);
        emit TokensVested(msg.sender, claimableAmount);
    }
    
    function _calculateVestedAmount(VestingSchedule memory schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.cliffEnd) return 0;
        if (block.timestamp >= schedule.endTime) return schedule.totalAmount;
        
        uint256 timeFromStart = block.timestamp - schedule.cliffEnd;
        uint256 vestingTime = schedule.endTime - schedule.cliffEnd;
        
        return (schedule.totalAmount * timeFromStart) / vestingTime;
    }
    
    // Staking functions
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Harvest any pending rewards first
        _harvestRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] += amount;
        stakingStartTime[msg.sender] = block.timestamp;
        
        // Transfer tokens to contract
        _transfer(msg.sender, address(this), amount);
        
        emit Staked(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient staked balance");
        
        // Harvest any pending rewards first
        _harvestRewards(msg.sender);
        
        // Update staking info
        stakedBalance[msg.sender] -= amount;
        
        // Transfer tokens back to user
        _transfer(address(this), msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function _harvestRewards(address user) internal {
        uint256 pending = pendingRewards(user);
        if (pending > 0) {
            rewardDebt[user] = block.timestamp;
            _mint(user, pending); // Mint new tokens as rewards, up to MAX_SUPPLY
            emit RewardPaid(user, pending);
        }
    }
    
    function pendingRewards(address user) public view returns (uint256) {
        if (stakedBalance[user] == 0) return 0;
        
        uint256 timeStaked = block.timestamp - stakingStartTime[user];
        uint256 baseReward = (stakedBalance[user] * timeStaked * 15) / (365 days * 100); // 15% APY
        
        // Apply multiplier based on amount staked
        uint256 multiplier = _calculateMultiplier(stakedBalance[user]);
        return (baseReward * multiplier) / 100;
    }
    
    function _calculateMultiplier(uint256 amount) internal pure returns (uint256) {
        // Tier 1: < 10,000 D4L = 100% (base)
        if (amount < 10_000 * 1e18) return 100;
        // Tier 2: 10,000-50,000 D4L = 125%
        if (amount < 50_000 * 1e18) return 125;
        // Tier 3: 50,000-100,000 D4L = 150%
        if (amount < 100_000 * 1e18) return 150;
        // Tier 4: > 100,000 D4L = 200%
        return 200;
    }
    
    // Override transfer functions to handle fees and restrictions
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        
        if (from != governanceAddress && to != governanceAddress) {
            require(!paused(), "Transfers paused");
        }
        
        // Calculate and apply fees if needed
        uint256 fee = _calculateFee(from, to, amount);
        uint256 netAmount = amount - fee;
        
        if (fee > 0) {
            super._transfer(from, address(this), fee);
            tokenomics.distributeFees(fee);
        }
        
        super._transfer(from, to, netAmount);
    }
    
    function _calculateFee(
        address from,
        address to,
        uint256 amount
    ) internal view returns (uint256) {
        if (from == governanceAddress || to == governanceAddress) return 0;
        if (from == address(this) || to == address(this)) return 0;
        return tokenomics.calculateTotalFees(amount);
    }
    
    // Required overrides
    function _mint(address account, uint256 amount) internal virtual override {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        super._mint(account, amount);
    }
} 