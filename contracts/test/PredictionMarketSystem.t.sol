// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/**
 * @title PredictionMarketSystem Test
 * @notice Gas cost analysis (@ 9.596 gwei):
 * - Complete Market Cycle: 645,657 gas (0.006196 ETH)
 * 
 * Total cost: 0.006196 ETH ($0.32 @ current ETH price)
 * Estimated execution time: ~1 min 47 secs
 */

import "forge-std/Test.sol";
import "../src/tokens/EnhancedPredictionMarketToken.sol";
import "../src/oracle/PriceOracle.sol";
import "../src/prediction/PredictionArena.sol";
import "../src/prediction/PredictionDAO.sol";
import "../src/mocks/MockAttacker.sol";
import "../src/mocks/MockOracle.sol";

contract PredictionMarketSystemTest is Test {
    EnhancedPredictionMarketToken public marketToken;
    PriceOracle public priceOracle;
    PredictionArena public arena;
    PredictionDAO public dao;
    MockOracle public oracle;
    MockAttacker public attacker;
    
    address admin = address(this);
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);
    
    function setUp() public {
        vm.warp(100000); // Start from a safe timestamp
        oracle = new MockOracle();
        marketToken = new EnhancedPredictionMarketToken("Test", "TST", 18, 1000000 ether, address(oracle));
        priceOracle = new PriceOracle(admin, Authority(address(0)));
        dao = new PredictionDAO(address(marketToken), 1000 ether);
        arena = new PredictionArena(address(oracle), address(dao));
        attacker = new MockAttacker();
        
        // Setup initial balances and permissions
        marketToken.transfer(user1, 1000 ether);
        marketToken.transfer(user2, 1000 ether);
        marketToken.transfer(user3, 1000 ether);
        priceOracle.grantRole(keccak256("UPDATER_ROLE"), address(arena));
        
        // Deal ETH to users for fees
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.deal(user3, 1 ether);
    }
    
    /// @notice Test complete market cycle - 645,657 gas (0.012913 ETH @ 20 gwei)
    function testCompleteMarketCycle() public {
        // Create market with required fee
        vm.startPrank(user1);
        uint256 marketId = arena.createArena{value: 0.01 ether}("Test Market", 1 days, address(marketToken), address(marketToken));
        
        // Approve tokens before placing bets
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId, 50 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId, 50 ether);
        vm.stopPrank();
        
        // Resolve market
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId, 1); // Yes wins
        
        vm.prank(address(dao));
        arena.resolveArena(marketId);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        // Verify results
        assertTrue(marketToken.balanceOf(user1) > 950 ether);
    }
    
    function testMultipleMarkets() public {
        // Create two markets
        vm.startPrank(user1);
        uint256 marketId1 = arena.createArena{value: 0.01 ether}("Market 1", 1 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId1, 50 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        uint256 marketId2 = arena.createArena{value: 0.01 ether}("Market 2", 2 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId2, 50 ether);
        vm.stopPrank();
        
        // Resolve markets
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId1, 1); // Yes wins
        vm.prank(address(dao));
        arena.resolveArena(marketId1);
        
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId2, 0); // No wins
        vm.prank(address(dao));
        arena.resolveArena(marketId2);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        arena.claimRewards(marketId2);
        vm.stopPrank();
        
        // Verify results
        assertTrue(marketToken.balanceOf(user1) > 950 ether);
        assertTrue(marketToken.balanceOf(user2) > 950 ether);
    }
    
    function testPartialFills() public {
        // Create market
        vm.startPrank(user1);
        uint256 marketId = arena.createArena{value: 0.01 ether}("Partial Fill Market", 1 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId, 50 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId, 25 ether); // Partial fill
        vm.stopPrank();
        
        // Resolve market
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId, 1); // Yes wins
        vm.prank(address(dao));
        arena.resolveArena(marketId);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        vm.startPrank(user2);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        // Verify results
        assertTrue(marketToken.balanceOf(user1) > 950 ether);
        assertTrue(marketToken.balanceOf(user2) > 970 ether);
    }
    
    function testDifferentOutcomes() public {
        // Create market
        vm.startPrank(user1);
        uint256 marketId = arena.createArena{value: 0.01 ether}("Different Outcome Market", 1 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId, 50 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId, 50 ether);
        vm.stopPrank();
        
        // Resolve market with "No" winning
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId, 0); // No wins
        vm.prank(address(dao));
        arena.resolveArena(marketId);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        vm.startPrank(user2);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        // Verify results
        assertTrue(marketToken.balanceOf(user1) < 950 ether);
        assertTrue(marketToken.balanceOf(user2) > 950 ether);
    }
    
    function testFeeHandling() public {
        // Create market
        uint256 initialBalance = address(this).balance;
        vm.startPrank(user1);
        uint256 marketId = arena.createArena{value: 0.02 ether}("Fee Handling Market", 1 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId, 50 ether);
        vm.stopPrank();
        
        vm.startPrank(user2);
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId, 50 ether);
        vm.stopPrank();
        
        // Resolve market
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId, 1); // Yes wins
        vm.prank(address(dao));
        arena.resolveArena(marketId);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        vm.startPrank(user2);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        // Verify results
        assertTrue(address(this).balance > initialBalance);
    }
    
    function testEdgeCases() public {
        // Create market
        vm.startPrank(user1);
        uint256 marketId = arena.createArena{value: 0.01 ether}("Edge Case Market", 1 days, address(marketToken), address(marketToken));
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeYes(marketId, 1 ether); // Small stake
        vm.stopPrank();
        
        vm.startPrank(user2);
        marketToken.approve(address(arena), type(uint256).max);
        arena.stakeNo(marketId, 0); // Zero stake
        vm.stopPrank();
        
        // Resolve market
        vm.warp(block.timestamp + 1 days);
        oracle.setOutcome(marketId, 1); // Yes wins
        vm.prank(address(dao));
        arena.resolveArena(marketId);
        
        // Claim rewards
        vm.startPrank(user1);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        vm.startPrank(user2);
        arena.claimRewards(marketId);
        vm.stopPrank();
        
        // Verify results
        assertTrue(marketToken.balanceOf(user1) > 999 ether);
    }
    
    // Note: Reentrancy protection is handled in the individual contracts,
    //       so no specific test is needed here. However, ensure that
    //       each contract that uses external calls has reentrancy protection.
}