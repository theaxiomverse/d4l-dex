// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "../tokens/EnhancedPredictionMarketToken.sol";
import "../interfaces/IPredictionArena.sol";
import "../interfaces/IOracle.sol";

contract PredictionArena is IPredictionArena {
    struct Arena {
        string name;
        address yesToken;    // Token representing "Yes" position
        address noToken;     // Token representing "No" position
        uint256 startTime;
        uint256 endTime;
        bool isResolved;
        bool outcome;        // true for Yes wins, false for No wins
        uint256 totalStaked; // Total amount staked in this arena
        mapping(address => uint256) yesStakes;
        mapping(address => uint256) noStakes;
    }

    mapping(uint256 => Arena) public arenas;
    uint256 public arenaCount;
    
    IOracle public oracle;
    address public dao;
    uint256 public stakingFee;     // Fee taken from stakes
    uint256 public creationFee;    // Fee to create new arena

    event ArenaCreated(uint256 indexed arenaId, string name, address yesToken, address noToken);
    event StakePlaced(uint256 indexed arenaId, address indexed staker, bool isYes, uint256 amount);
    event ArenaResolved(uint256 indexed arenaId, bool outcome);
    event RewardsClaimed(uint256 indexed arenaId, address indexed staker, uint256 amount);

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call this");
        _;
    }

    constructor(address _oracle, address _dao) {
        oracle = IOracle(_oracle);
        dao = _dao;
        stakingFee = 0.003 ether;  // 0.3% fee
        creationFee = 0.01 ether;  // 0.01 ETH to create arena
    }

    function createArena(
        string calldata name,
        uint256 duration,
        address yesToken,
        address noToken
    ) external payable returns (uint256 arenaId) {
        require(msg.value >= creationFee, "Insufficient creation fee");
        
        arenaId = arenaCount++;
        Arena storage arena = arenas[arenaId];
        arena.name = name;
        arena.yesToken = yesToken;
        arena.noToken = noToken;
        arena.startTime = block.timestamp;
        arena.endTime = block.timestamp + duration;
        arena.isResolved = false;

        emit ArenaCreated(arenaId, name, yesToken, noToken);
        return arenaId;
    }

    function stakeYes(uint256 arenaId, uint256 amount) external {
        Arena storage arena = arenas[arenaId];
        require(!arena.isResolved, "Arena already resolved");
        require(block.timestamp < arena.endTime, "Arena ended");

        uint256 fee = (amount * stakingFee) / 1e18;
        uint256 stakeAmount = amount - fee;

        IERC20(arena.yesToken).transferFrom(msg.sender, address(this), amount);
        arena.yesStakes[msg.sender] += stakeAmount;
        arena.totalStaked += stakeAmount;

        emit StakePlaced(arenaId, msg.sender, true, stakeAmount);
    }

    function stakeNo(uint256 arenaId, uint256 amount) external {
        Arena storage arena = arenas[arenaId];
        require(!arena.isResolved, "Arena already resolved");
        require(block.timestamp < arena.endTime, "Arena ended");

        uint256 fee = (amount * stakingFee) / 1e18;
        uint256 stakeAmount = amount - fee;

        IERC20(arena.noToken).transferFrom(msg.sender, address(this), amount);
        arena.noStakes[msg.sender] += stakeAmount;
        arena.totalStaked += stakeAmount;

        emit StakePlaced(arenaId, msg.sender, false, stakeAmount);
    }

    function resolveArena(uint256 arenaId) external {
        Arena storage arena = arenas[arenaId];
        require(!arena.isResolved, "Already resolved");
        require(block.timestamp >= arena.endTime, "Arena not ended");

        arena.outcome = oracle.getOutcome(arenaId) > 0;
        arena.isResolved = true;

        emit ArenaResolved(arenaId, arena.outcome);
    }

    function claimRewards(uint256 arenaId) external {
        Arena storage arena = arenas[arenaId];
        require(arena.isResolved, "Arena not resolved");

        uint256 reward;
        if (arena.outcome) {
            reward = arena.yesStakes[msg.sender];
            arena.yesStakes[msg.sender] = 0;
        } else {
            reward = arena.noStakes[msg.sender];
            arena.noStakes[msg.sender] = 0;
        }

        require(reward > 0, "No rewards to claim");

        // Calculate proportional share of total stakes
        uint256 totalReward = (reward * arena.totalStaked) / 
            (arena.outcome ? getTotalYesStakes(arenaId) : getTotalNoStakes(arenaId));

        if (arena.outcome) {
            IERC20(arena.yesToken).transfer(msg.sender, totalReward);
        } else {
            IERC20(arena.noToken).transfer(msg.sender, totalReward);
        }

        emit RewardsClaimed(arenaId, msg.sender, totalReward);
    }

    function getTotalYesStakes(uint256 arenaId) public view returns (uint256 total) {
        Arena storage arena = arenas[arenaId];
        return arena.totalStaked;
    }

    function getTotalNoStakes(uint256 arenaId) public view returns (uint256 total) {
        Arena storage arena = arenas[arenaId];
        return arena.totalStaked;
    }

    // DAO functions
    function updateStakingFee(uint256 newFee) external onlyDAO {
        stakingFee = newFee;
    }

    function updateCreationFee(uint256 newFee) external onlyDAO {
        creationFee = newFee;
    }

    function updateDAO(address newDAO) external onlyDAO {
        dao = newDAO;
    }
} 