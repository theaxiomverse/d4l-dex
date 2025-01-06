// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/prediction/PredictionArena.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockOracle.sol";

contract PredictionArenaTest is Test {
    PredictionArena public arena;
    MockOracle public oracle;
    MockERC20 public yesToken;
    MockERC20 public noToken;
    
    address public constant OWNER = address(0x1);
    address public constant USER1 = address(0x2);
    address public constant USER2 = address(0x3);
    address public constant DAO = address(0x4);
    
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant STAKE_AMOUNT = 10 ether;
    uint256 public constant ARENA_DURATION = 7 days;
    
    event ArenaCreated(uint256 indexed arenaId, string name, address yesToken, address noToken);
    event StakePlaced(uint256 indexed arenaId, address indexed staker, bool isYes, uint256 amount);
    event ArenaResolved(uint256 indexed arenaId, bool outcome);
    event RewardsClaimed(uint256 indexed arenaId, address indexed staker, uint256 amount);
    
    function setUp() public {
        // Deploy contracts
        oracle = new MockOracle();
        arena = new PredictionArena(address(oracle), DAO);
        yesToken = new MockERC20("Yes Token", "YES", 18);
        noToken = new MockERC20("No Token", "NO", 18);
        
        // Fund users
        vm.deal(USER1, 100 ether);
        vm.deal(USER2, 100 ether);
        
        yesToken.mint(USER1, INITIAL_BALANCE);
        yesToken.mint(USER2, INITIAL_BALANCE);
        noToken.mint(USER1, INITIAL_BALANCE);
        noToken.mint(USER2, INITIAL_BALANCE);
        
        vm.startPrank(USER1);
        yesToken.approve(address(arena), type(uint256).max);
        noToken.approve(address(arena), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(USER2);
        yesToken.approve(address(arena), type(uint256).max);
        noToken.approve(address(arena), type(uint256).max);
        vm.stopPrank();
    }
    
    function testInitialSetup() public {
        assertEq(address(arena.oracle()), address(oracle));
        assertEq(arena.dao(), DAO);
        assertEq(arena.stakingFee(), 0.003 ether);
        assertEq(arena.creationFee(), 0.01 ether);
        assertEq(arena.arenaCount(), 0);
    }
    
    function testCreateArena() public {
        string memory name = "Test Arena";
        
        vm.startPrank(USER1);
        
        vm.expectEmit(true, false, false, true);
        emit ArenaCreated(0, name, address(yesToken), address(noToken));
        
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            name,
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        assertEq(arenaId, 0);
        assertEq(arena.arenaCount(), 1);
        
        (string memory storedName, address storedYesToken, address storedNoToken, uint256 startTime, uint256 endTime, bool isResolved, bool outcome, uint256 totalStaked) = arena.arenas(arenaId);
        
        assertEq(storedName, name);
        assertEq(storedYesToken, address(yesToken));
        assertEq(storedNoToken, address(noToken));
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + ARENA_DURATION);
        assertEq(isResolved, false);
        assertEq(outcome, false);
        assertEq(totalStaked, 0);
        
        vm.stopPrank();
    }
    
    function testFailCreateArenaInsufficientFee() public {
        vm.prank(USER1);
        arena.createArena{value: 0.009 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
    }
    
    function testStakeYes() public {
        // Create arena
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        // Place stake
        vm.startPrank(USER1);
        
        uint256 initialBalance = yesToken.balanceOf(USER1);
        
        vm.expectEmit(true, true, false, true);
        emit StakePlaced(arenaId, USER1, true, STAKE_AMOUNT - (STAKE_AMOUNT * 0.003 ether / 1e18));
        
        arena.stakeYes(arenaId, STAKE_AMOUNT);
        
        // Verify stake
        assertEq(yesToken.balanceOf(USER1), initialBalance - STAKE_AMOUNT);
        assertEq(yesToken.balanceOf(address(arena)), STAKE_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testStakeNo() public {
        // Create arena
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        // Place stake
        vm.startPrank(USER2);
        
        uint256 initialBalance = noToken.balanceOf(USER2);
        
        vm.expectEmit(true, true, false, true);
        emit StakePlaced(arenaId, USER2, false, STAKE_AMOUNT - (STAKE_AMOUNT * 0.003 ether / 1e18));
        
        arena.stakeNo(arenaId, STAKE_AMOUNT);
        
        // Verify stake
        assertEq(noToken.balanceOf(USER2), initialBalance - STAKE_AMOUNT);
        assertEq(noToken.balanceOf(address(arena)), STAKE_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testFailStakeAfterEnd() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        
        vm.prank(USER1);
        arena.stakeYes(arenaId, STAKE_AMOUNT);
    }
    
    function testFailStakeInResolvedArena() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        arena.resolveArena(arenaId);
        
        vm.prank(USER1);
        arena.stakeYes(arenaId, STAKE_AMOUNT);
    }
    
    function testResolveArena() public {
        // Create and stake in arena
        vm.startPrank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        arena.stakeYes(arenaId, STAKE_AMOUNT);
        vm.stopPrank();
        
        vm.prank(USER2);
        arena.stakeNo(arenaId, STAKE_AMOUNT);
        
        // Set oracle outcome
        oracle.setOutcome(arenaId, 1); // Yes wins
        
        // Wait for arena to end
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        
        vm.expectEmit(true, false, false, true);
        emit ArenaResolved(arenaId, true);
        
        arena.resolveArena(arenaId);
        
        // Verify resolution
        (,,,,, bool isResolved, bool outcome,) = arena.arenas(arenaId);
        assertTrue(isResolved);
        assertTrue(outcome);
    }
    
    function testFailResolveBeforeEnd() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        arena.resolveArena(arenaId);
    }
    
    function testFailResolveAlreadyResolved() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        arena.resolveArena(arenaId);
        arena.resolveArena(arenaId);
    }
    
    function testClaimRewards() public {
        // Create and stake in arena
        vm.startPrank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        arena.stakeYes(arenaId, STAKE_AMOUNT);
        vm.stopPrank();
        
        vm.prank(USER2);
        arena.stakeNo(arenaId, STAKE_AMOUNT);
        
        // Set oracle outcome and resolve
        oracle.setOutcome(arenaId, 1); // Yes wins
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        arena.resolveArena(arenaId);
        
        // Calculate expected reward
        uint256 fee = (STAKE_AMOUNT * 0.003 ether) / 1e18;
        uint256 netStake = STAKE_AMOUNT - fee;
        
        // Claim rewards
        vm.startPrank(USER1);
        uint256 initialBalance = yesToken.balanceOf(USER1);
        
        vm.expectEmit(true, true, false, true);
        emit RewardsClaimed(arenaId, USER1, netStake);
        
        arena.claimRewards(arenaId);
        
        // Verify rewards
        assertEq(yesToken.balanceOf(USER1), initialBalance + netStake);
        
        vm.stopPrank();
    }
    
    function testFailClaimBeforeResolution() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        vm.prank(USER1);
        arena.claimRewards(arenaId);
    }
    
    function testFailClaimWithNoStake() public {
        vm.prank(USER1);
        uint256 arenaId = arena.createArena{value: 0.01 ether}(
            "Test Arena",
            ARENA_DURATION,
            address(yesToken),
            address(noToken)
        );
        
        vm.warp(block.timestamp + ARENA_DURATION + 1);
        arena.resolveArena(arenaId);
        
        vm.prank(USER2); // USER2 has no stake
        arena.claimRewards(arenaId);
    }
    
    function testUpdateStakingFee() public {
        uint256 newFee = 0.005 ether;
        
        vm.prank(DAO);
        arena.updateStakingFee(newFee);
        
        assertEq(arena.stakingFee(), newFee);
    }
    
    function testFailUpdateStakingFeeUnauthorized() public {
        vm.prank(USER1);
        arena.updateStakingFee(0.005 ether);
    }
    
    function testUpdateCreationFee() public {
        uint256 newFee = 0.02 ether;
        
        vm.prank(DAO);
        arena.updateCreationFee(newFee);
        
        assertEq(arena.creationFee(), newFee);
    }
    
    function testFailUpdateCreationFeeUnauthorized() public {
        vm.prank(USER1);
        arena.updateCreationFee(0.02 ether);
    }
    
    function testUpdateDAO() public {
        address newDAO = address(0x5);
        
        vm.prank(DAO);
        arena.updateDAO(newDAO);
        
        assertEq(arena.dao(), newDAO);
    }
    
    function testFailUpdateDAOUnauthorized() public {
        vm.prank(USER1);
        arena.updateDAO(address(0x5));
    }
} 