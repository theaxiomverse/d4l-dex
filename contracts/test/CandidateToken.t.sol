// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/tokens/CandidateToken.sol";

contract CandidateTokenTest is Test {
    CandidateToken public token;
    
    address public constant OWNER = address(0x1);
    address public constant USER1 = address(0x2);
    address public constant USER2 = address(0x3);
    
    uint256 public constant DURATION = 7 days;
    uint256 public constant BET_AMOUNT = 1 ether;
    
    // Test market data
    string[] candidateNames;
    string[] candidateDescriptions;
    string[] candidateImageURIs;
    
    function setUp() public {
        vm.startPrank(OWNER);
        token = new CandidateToken();
        vm.stopPrank();
        
        // Setup test data
        candidateNames.push("Democrats");
        candidateNames.push("Republicans");
        
        candidateDescriptions.push("Democratic Party");
        candidateDescriptions.push("Republican Party");
        
        candidateImageURIs.push("ipfs://dem");
        candidateImageURIs.push("ipfs://rep");
    }
    
    function testCreateMarket() public {
        vm.prank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        // Get market data
        (
            uint256[] memory candidateIds,
            string[] memory names,
            string[] memory descriptions,
            string[] memory imageURIs,
            uint256[] memory currentPrices,
            uint256[] memory totalSupplies
        ) = token.getMarketCandidates(marketId);
        
        // Verify market data
        assertEq(names.length, 2);
        assertEq(names[0], "Democrats");
        assertEq(names[1], "Republicans");
        
        // Verify initial odds are equal
        (uint256[] memory ids, uint256[] memory odds) = token.getMarketOdds(marketId);
        assertEq(odds[0], 5000); // 50%
        assertEq(odds[1], 5000); // 50%
    }
    
    function testRecordBet() public {
        // Create market
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        // Get candidate IDs
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        
        // Record bets
        token.recordBet(candidateIds[0], USER1, BET_AMOUNT, 1 ether); // Bet on Democrats
        token.recordBet(candidateIds[1], USER2, BET_AMOUNT / 2, 1 ether); // Bet on Republicans
        vm.stopPrank();
        
        // Verify odds updated correctly
        (, uint256[] memory odds) = token.getMarketOdds(marketId);
        assertEq(odds[0], 6666); // ~66.66%
        assertEq(odds[1], 3333); // ~33.33%
        
        // Verify token balances
        assertEq(token.balanceOf(USER1, candidateIds[0]), BET_AMOUNT);
        assertEq(token.balanceOf(USER2, candidateIds[1]), BET_AMOUNT / 2);
    }
    
    function testGetMarketStats() public {
        // Create market
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        // Get candidate IDs
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        
        // Record bets
        token.recordBet(candidateIds[0], USER1, BET_AMOUNT, 1 ether);
        token.recordBet(candidateIds[1], USER2, BET_AMOUNT, 1 ether);
        vm.stopPrank();
        
        // Get market stats
        (
            uint256 totalVolume,
            uint256[] memory ids,
            uint256[] memory volumes,
            uint256[] memory odds
        ) = token.getMarketStats(marketId);
        
        // Verify stats
        assertEq(totalVolume, BET_AMOUNT * 2);
        assertEq(volumes[0], BET_AMOUNT);
        assertEq(volumes[1], BET_AMOUNT);
        assertEq(odds[0], 5000); // 50%
        assertEq(odds[1], 5000); // 50%
    }
    
    function testGetPriceHistory() public {
        // Create market
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        // Get candidate IDs
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        
        // Record bets at different times
        token.recordBet(candidateIds[0], USER1, BET_AMOUNT, 1 ether);
        vm.warp(block.timestamp + 1 days);
        token.recordBet(candidateIds[0], USER2, BET_AMOUNT, 2 ether);
        vm.stopPrank();
        
        // Get price history
        (
            uint256[] memory timestamps,
            uint256[] memory prices,
            uint256[] memory supplies
        ) = token.getPriceHistory(candidateIds[0], 0, block.timestamp);
        
        // Verify history
        assertEq(prices.length, 3); // Initial + 2 bets
        assertEq(prices[0], 0);
        assertEq(prices[1], 1 ether);
        assertEq(prices[2], 2 ether);
        
        assertEq(supplies[0], 0);
        assertEq(supplies[1], BET_AMOUNT);
        assertEq(supplies[2], BET_AMOUNT * 2);
    }
    
    function testResolveMarket() public {
        // Create market
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        // Get candidate IDs
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        
        // Record bets
        token.recordBet(candidateIds[0], USER1, BET_AMOUNT, 1 ether);
        token.recordBet(candidateIds[1], USER2, BET_AMOUNT, 1 ether);
        
        // Wait for market to end
        vm.warp(block.timestamp + DURATION + 1);
        
        // Resolve market
        token.resolveMarket(marketId, candidateIds[0]); // Democrats win
        vm.stopPrank();
        
        // Verify market resolved
        (bool resolved, uint256 winner) = token.getMarketResolution(marketId);
        assertTrue(resolved);
        assertEq(winner, candidateIds[0]);
    }
    
    function testFailResolveBeforeEnd() public {
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        token.resolveMarket(marketId, candidateIds[0]); // Should fail
    }
    
    function testFailResolveUnauthorized() public {
        vm.prank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        (uint256[] memory candidateIds,,,,, ) = token.getMarketCandidates(marketId);
        
        vm.warp(block.timestamp + DURATION + 1);
        vm.prank(USER1);
        token.resolveMarket(marketId, candidateIds[0]); // Should fail
    }
    
    function testFailInvalidCandidateId() public {
        vm.startPrank(OWNER);
        uint256 marketId = token.createMarket(
            "US Election 2024",
            "Presidential Election",
            DURATION,
            candidateNames,
            candidateDescriptions,
            candidateImageURIs
        );
        
        token.recordBet(999, USER1, BET_AMOUNT, 1 ether); // Should fail
    }
} 