// test/EnhancedPredictionMarketToken.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/tokens/EnhancedPredictionMarketToken.sol";
import "../src/mocks/MockOracle.sol";

contract EnhancedPredictionMarketTokenTest is Test {
    EnhancedPredictionMarketToken predictionMarketToken;
    MockOracle oracle;

    address owner;
    address addr1;
    address addr2;

    // Cache commonly used values
    uint256 constant MARKET_CREATION_FEE = 0.01 ether;
    uint256 constant BETTING_FEE = 0.001 ether;
    uint256 constant INITIAL_BALANCE = 100 ether;
    
    // Cache commonly used array
    string[] testOutcomes;

    function setUp() public {
        oracle = new MockOracle();
        predictionMarketToken = new EnhancedPredictionMarketToken(
            "TestToken", 
            "TTK", 
            18, 
            1000 ether, 
            address(oracle)
        );
        
        owner = address(this);
        addr1 = address(0x1);
        addr2 = address(0x2);
        
        // Setup default outcomes
        testOutcomes = new string[](2);
        testOutcomes[0] = "Outcome 1";
        testOutcomes[1] = "Outcome 2";
        
        predictionMarketToken.transfer(addr1, INITIAL_BALANCE);
    }

    function testCreateMarket() public {
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        (string memory question, string[] memory marketOutcomes, , , , , ) = predictionMarketToken.getMarket(marketId);
        assertEq(question, "Test Question?");
        assertEq(marketOutcomes[0], "Outcome 1");
        assertEq(marketOutcomes[1], "Outcome 2");
    }

    function testPlaceBet() public {
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        vm.prank(addr1);
        predictionMarketToken.placeBet(marketId, 0, 10 ether);

        ( , , uint256 totalBets, uint256[] memory outcomeBets, , , ) = predictionMarketToken.getMarket(marketId);
        assertEq(totalBets, 10 ether);
        assertEq(outcomeBets[0], 10 ether);
    }

    function testResolveMarket() public {
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        vm.prank(addr1);
        predictionMarketToken.placeBet(marketId, 0, 10 ether);

        oracle.setOutcome(marketId, 0);
        vm.prank(owner);
        predictionMarketToken.resolveMarket(marketId);

        ( , , , , bool isResolved, uint256 winningOutcomeIndex, ) = predictionMarketToken.getMarket(marketId);
        assertTrue(isResolved);
        assertEq(winningOutcomeIndex, 0);
    }

    function testWithdrawWinnings() public {
        uint256 initialBalance = predictionMarketToken.balanceOf(addr1);
        
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        vm.prank(addr1);
        predictionMarketToken.placeBet(marketId, 0, 10 ether);

        oracle.setOutcome(marketId, 0);
        vm.prank(owner);
        predictionMarketToken.resolveMarket(marketId);

        vm.prank(addr1);
        predictionMarketToken.withdrawWinnings(marketId);

        // Calculate expected balance:
        // Initial balance - market creation fee - betting fee - bet amount + winnings
        uint256 expectedBalance = initialBalance - 0.01 ether - 0.001 ether - 10 ether + 10 ether;
        assertEq(predictionMarketToken.balanceOf(addr1), expectedBalance);
    }

    function testFuzz_PlaceBet(uint256 betAmount) public {
        // Bound bet amount between 0.1 ether and 50 ether
        betAmount = bound(betAmount, 0.1 ether, 50 ether);
        
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        vm.prank(addr1);
        predictionMarketToken.placeBet(marketId, 0, betAmount);

        ( , , uint256 totalBets, uint256[] memory outcomeBets, , , ) = predictionMarketToken.getMarket(marketId);
        assertEq(totalBets, betAmount);
        assertEq(outcomeBets[0], betAmount);
    }

    function testFuzz_MultipleOutcomes(uint8 numOutcomes) public {
        // Bound number of outcomes between 2 and 10
        numOutcomes = uint8(bound(numOutcomes, 2, 10));
        
        string[] memory outcomes = new string[](numOutcomes);
        for(uint8 i = 0; i < numOutcomes; i++) {
            outcomes[i] = string(abi.encodePacked("Outcome ", vm.toString(i)));
        }

        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", outcomes);

        ( , string[] memory marketOutcomes, , , , , ) = predictionMarketToken.getMarket(marketId);
        assertEq(marketOutcomes.length, numOutcomes);
    }

    function testFuzz_MultipleBettors(uint8 numBettors, uint256 betAmount) public {
        numBettors = uint8(bound(numBettors, 2, 10));
        betAmount = bound(betAmount, 0.1 ether, 10 ether);

        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        uint256 totalExpectedBets;
        address bettor;

        unchecked {
            for(uint8 i = 1; i <= numBettors; i++) {
                bettor = address(uint160(i));
                predictionMarketToken.transfer(bettor, betAmount + 1 ether);
                
                vm.prank(bettor);
                predictionMarketToken.placeBet(marketId, 0, betAmount);
                
                totalExpectedBets += betAmount;
            }
        }

        ( , , uint256 totalBets, uint256[] memory outcomeBets, , , ) = predictionMarketToken.getMarket(marketId);
        assertEq(totalBets, totalExpectedBets);
        assertEq(outcomeBets[0], totalExpectedBets);
    }

    function testFuzz_WithdrawWinnings(uint256 betAmount) public {
        // Bound bet amount between 0.1 ether and 50 ether
        betAmount = bound(betAmount, 0.1 ether, 50 ether);

        uint256 initialBalance = predictionMarketToken.balanceOf(addr1);
        
        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", testOutcomes);

        vm.prank(addr1);
        predictionMarketToken.placeBet(marketId, 0, betAmount);

        oracle.setOutcome(marketId, 0);
        vm.prank(owner);
        predictionMarketToken.resolveMarket(marketId);

        vm.prank(addr1);
        predictionMarketToken.withdrawWinnings(marketId);

        uint256 expectedBalance = initialBalance - 0.01 ether - 0.001 ether - betAmount + betAmount;
        assertEq(predictionMarketToken.balanceOf(addr1), expectedBalance);
    }

    function testFuzz_MarketResolution(uint8 winningOutcome) public {
        // Create outcomes array for this specific test
        string[] memory outcomes = new string[](3);
        outcomes[0] = "Outcome 1";
        outcomes[1] = "Outcome 2";
        outcomes[2] = "Outcome 3";

        // Bound winning outcome to valid range
        winningOutcome = uint8(bound(winningOutcome, 0, 2));

        vm.prank(addr1);
        uint256 marketId = predictionMarketToken.createMarket("Test Question?", outcomes);

        oracle.setOutcome(marketId, winningOutcome);
        vm.prank(owner);
        predictionMarketToken.resolveMarket(marketId);

        ( , , , , bool isResolved, uint256 actualWinningOutcome, ) = predictionMarketToken.getMarket(marketId);
        assertTrue(isResolved);
        assertEq(actualWinningOutcome, winningOutcome);
    }
}