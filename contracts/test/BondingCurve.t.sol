// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/liquidity/BondingCurve.sol";
import "../src/mocks/MockERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract BondingCurveTest is Test {
    using FixedPointMathLib for uint256;
    
    BondingCurve public curve;
    MockERC20 public token;
    
    address public constant OWNER = address(0x1);
    address public constant USER = address(0x2);
    
    uint256 public constant INITIAL_SUPPLY = 100_000_000 ether;
    uint256 public constant INITIAL_ETH = 100 ether;
    uint256 public constant BASE_PRICE = 1 ether;
    uint256 public constant SLOPE = 1 ether;  // Price increases by 1 ETH per ETH invested
    
    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        
        // First mint tokens to this contract
        token.mint(address(this), INITIAL_SUPPLY);
        
        // Create curve
        curve = new BondingCurve(
            address(token),
            OWNER,
            Authority(address(0)),
            BASE_PRICE,
            SLOPE
        );
        
        // Approve and transfer tokens to curve
        token.approve(address(curve), INITIAL_SUPPLY);
        token.transfer(address(curve), INITIAL_SUPPLY);
        
        // Setup initial pool state with ETH
        vm.deal(address(curve), INITIAL_ETH);
        
        // Update pool state
        vm.prank(OWNER);
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, BASE_PRICE);
        
        // Fund users
        vm.deal(USER, 100 * 1e18); // 100 ETH
        token.mint(USER, INITIAL_SUPPLY);
        
        vm.prank(USER);
        token.approve(address(curve), type(uint256).max);
    }
    
    function testInitialSetup() public view {
        assertEq(token.balanceOf(address(curve)), INITIAL_SUPPLY);
        assertEq(address(curve).balance, INITIAL_ETH);
        
        (uint256 basePrice, uint256 slope, uint256 maxPrice, uint256 minPrice) = curve.curveParams();
        assertEq(basePrice, BASE_PRICE);
        assertEq(slope, SLOPE);
        assertEq(maxPrice, BASE_PRICE * 10);
        assertEq(minPrice, BASE_PRICE / 10);
        
        (uint256 tokenBalance, uint256 ethBalance, uint256 lastPrice) = curve.poolState();
        assertEq(tokenBalance, INITIAL_SUPPLY);
        assertEq(ethBalance, INITIAL_ETH);
        assertEq(lastPrice, BASE_PRICE);
    }
    
    function testBuyPriceCalculation() public view {
        // Small purchase (0.1 ETH)
        uint256 smallAmount = 0.1 ether;
        uint256 smallPrice = curve.calculateBuyPrice(smallAmount);
        
        // Large purchase (1 ETH)
        uint256 largeAmount = 1 ether;
        uint256 largePrice = curve.calculateBuyPrice(largeAmount);
        
        // Price should increase with purchase size
        assertGt(largePrice, smallPrice, "Large purchase should have higher price");
        
        // Both prices should be above base price due to slope
        assertGt(smallPrice, BASE_PRICE, "Small price should be above base price");
        assertGt(largePrice, BASE_PRICE, "Large price should be above base price");
    }
    
    function testSellPriceCalculation() public {
        vm.startPrank(USER);
        
        // First buy some tokens
        uint256 buyAmount = 1 ether;
        uint256 minTokens = 0.1 ether;
        uint256 boughtAmount = curve.buyTokens{value: buyAmount}(minTokens);
        
        // Try to sell half
        uint256 sellAmount = boughtAmount / 2;
        uint256 sellPrice = curve.calculateSellPrice(sellAmount);
        
        // Sell price should be lower than current price
        assertTrue(sellPrice > 0, "Sell price should be positive");
        assertTrue(sellPrice < curve.calculateBuyPrice(buyAmount), "Sell price should be lower than buy price");
        
        vm.stopPrank();
    }
    
    function testBuyTokens() public {
        vm.startPrank(USER);
        uint256 ethAmount = 1 ether;
        uint256 minTokens = 0.1 ether;
        
        uint256 tokenAmount = curve.buyTokens{value: ethAmount}(minTokens);
        assertTrue(tokenAmount >= minTokens, "Should receive minimum tokens");
        assertGt(token.balanceOf(USER), INITIAL_SUPPLY, "Balance should increase");
        vm.stopPrank();
    }
    
    function testSellTokens() public {
        vm.startPrank(USER);
        
        // First buy tokens
        uint256 buyAmount = 1 ether;
        uint256 minTokens = 0.01 ether;
        uint256 boughtAmount = curve.buyTokens{value: buyAmount}(minTokens);
        
        // Then sell half
        uint256 sellAmount = boughtAmount / 2;
        uint256 minEthReturn = buyAmount / 8; // Expect at least 1/8 of original ETH due to price impact
        
        uint256 ethReceived = curve.sellTokens(sellAmount, minEthReturn);
        assertTrue(ethReceived >= minEthReturn, "Should receive minimum ETH amount");
        
        vm.stopPrank();
    }
    
    function testSlippageProtection() public {
        vm.startPrank(USER);
        uint256 ethAmount = 1 ether;
        uint256 minTokens = 100 ether; // Unreasonably high minimum tokens
        
        vm.expectRevert(BondingCurve.SlippageExceeded.selector);
        curve.buyTokens{value: ethAmount}(minTokens);
        vm.stopPrank();
    }
    
    function testPriceBounds() public {
        vm.startPrank(USER);
        // Fund USER with more ETH for this test
        vm.deal(USER, 10000 ether);
        
        // Try to buy with a very large amount to trigger price bounds
        uint256 largeAmount = 10000 ether;  // 10000 ETH should definitely exceed max price
        uint256 minTokens = 0.1 ether;
        
        vm.expectRevert(BondingCurve.PriceOutOfBounds.selector);
        curve.buyTokens{value: largeAmount}(minTokens);
        vm.stopPrank();
    }
    
    function testZeroAmountReverts() public {
        vm.startPrank(USER);
        
        // Test zero amount buy
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.calculateBuyPrice(0);
        
        // Test zero amount sell
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.calculateSellPrice(0);
        
        // Test zero amount buy transaction
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.buyTokens{value: 0}(0);
        
        // Test zero amount sell transaction
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.sellTokens(0, 0);
        
        vm.stopPrank();
    }

    function testInsufficientLiquidity() public {
        vm.startPrank(USER);
        
        // Test selling more than balance
        vm.expectRevert(BondingCurve.InsufficientLiquidity.selector);
        curve.calculateSellPrice(INITIAL_SUPPLY + 1);
        
        // Test selling more than available
        vm.expectRevert(BondingCurve.InsufficientLiquidity.selector);
        curve.sellTokens(INITIAL_SUPPLY + 1, 1 ether);
        
        vm.stopPrank();
    }

    function testMinPurchaseAmount() public {
        vm.startPrank(USER);
        
        // Test purchase below minimum
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.buyTokens{value: 0.009 ether}(0);
        
        vm.stopPrank();
    }

    function testUpdatePoolState() public {
        vm.startPrank(OWNER);
        
        // Test valid update
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, BASE_PRICE);
        
        // Test zero price
        vm.expectRevert(BondingCurve.InvalidAmount.selector);
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, 0);
        
        // Test price too high
        vm.expectRevert(BondingCurve.PriceOutOfBounds.selector);
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, BASE_PRICE * 11);
        
        // Test price too low
        vm.expectRevert(BondingCurve.PriceOutOfBounds.selector);
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, BASE_PRICE / 11);
        
        vm.stopPrank();
    }

    function testUnauthorizedUpdate() public {
        vm.startPrank(USER);
        
        // Test unauthorized pool state update
        vm.expectRevert("UNAUTHORIZED");
        curve.updatePoolState(INITIAL_SUPPLY, INITIAL_ETH, BASE_PRICE);
        
        vm.stopPrank();
    }

    function testReceiveEth() public {
        // Test direct ETH transfer
        (bool success,) = address(curve).call{value: 1 ether}("");
        assertTrue(success, "Should accept ETH");
    }
} 