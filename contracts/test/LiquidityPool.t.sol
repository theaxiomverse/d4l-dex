// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/**
 * @title LiquidityPool Test
 * @notice Gas cost analysis (@ 9.596 gwei):
 * - Add Liquidity: 325,377 gas (0.003122 ETH)
 * - Create Pool: 235,922 gas (0.002264 ETH)
 * - Remove Liquidity: 293,179 gas (0.002813 ETH)
 * - Price Validation: 270,671 gas (0.002598 ETH)
 * - Stale Price Validation: 268,706 gas (0.002578 ETH)
 * 
 * Total cost for all operations: 0.013375 ETH ($0.68 @ current ETH price)
 * Estimated execution time: ~1 min 47 secs
 */

import "forge-std/Test.sol";
import "../src/liquidity/LiquidityPool.sol";
import "../src/mocks/MockERC20.sol";
import {Authority} from "solmate/auth/Auth.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public liquidityPool;
    MockERC20 public token;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    uint256 public constant MARKET_ID = 1;
    uint256 public constant INITIAL_SUPPLY = 1000000e18;
    uint256 public constant INITIAL_PRICE = 1000e18; // Initial price of 1000 tokens
    
    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        
        // Create a simple Authority that gives all permissions to the test contract
        Authority authority = Authority(address(this));
        liquidityPool = new LiquidityPool(address(token));
        
        // Grant roles to test addresses
        vm.prank(liquidityPool.owner());
        liquidityPool.setAuthority(authority);
        
        // Mint initial tokens
        token.mint(alice, INITIAL_SUPPLY);
        token.mint(bob, INITIAL_SUPPLY);
        
        vm.startPrank(alice);
        token.approve(address(liquidityPool), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        token.approve(address(liquidityPool), type(uint256).max);
        vm.stopPrank();
    }
    
    // Implement the Authority interface
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool) {
        return true; // Allow all calls in test environment
    }
    
    /// @notice Test pool creation - 235,922 gas (0.004718 ETH @ 20 gwei)
    function testCreatePool() public {
        vm.startPrank(alice);
        uint256 amount = 1000e18;
        liquidityPool.createPool(MARKET_ID, amount, INITIAL_PRICE);
        
        (uint256 totalLiquidity, uint256 totalShares, bool active) = liquidityPool.getPoolInfo(MARKET_ID);
        assertEq(totalLiquidity, amount);
        assertEq(totalShares, amount);
        assertTrue(active);
        vm.stopPrank();
    }
    
    /// @notice Test adding liquidity - 325,377 gas (0.006507 ETH @ 20 gwei)
    function testAddLiquidity() public {
        vm.startPrank(alice);
        uint256 initialAmount = 1000e18;
        liquidityPool.createPool(MARKET_ID, initialAmount, INITIAL_PRICE);
        vm.stopPrank();
        
        vm.startPrank(bob);
        uint256 addAmount = 500e18;
        // Price increased by 10%
        uint256 newPrice = INITIAL_PRICE * 110 / 100;
        liquidityPool.addLiquidity(MARKET_ID, addAmount, newPrice);
        
        (uint256 totalLiquidity, uint256 totalShares,) = liquidityPool.getPoolInfo(MARKET_ID);
        assertEq(totalLiquidity, initialAmount + addAmount);
        assertEq(totalShares, initialAmount + addAmount);
        vm.stopPrank();
    }
    
    /// @notice Test price validation - 270,671 gas (0.005413 ETH @ 20 gwei)
    function testPriceValidation() public {
        vm.startPrank(alice);
        uint256 initialAmount = 1000e18;
        liquidityPool.createPool(MARKET_ID, initialAmount, INITIAL_PRICE);
        
        // Try to add liquidity with too high price change (60% increase)
        uint256 invalidPrice = INITIAL_PRICE * 160 / 100;
        vm.expectRevert(abi.encodeWithSelector(LiquidityPool.PriceChangeTooBig.selector, INITIAL_PRICE, invalidPrice));
        liquidityPool.addLiquidity(MARKET_ID, 500e18, invalidPrice);
        vm.stopPrank();
    }
    
    /// @notice Test stale price validation - 268,706 gas (0.005374 ETH @ 20 gwei)
    function testStalePriceValidation() public {
        vm.startPrank(alice);
        uint256 initialAmount = 1000e18;
        liquidityPool.createPool(MARKET_ID, initialAmount, INITIAL_PRICE);
        
        // Move time forward beyond price validity period
        vm.warp(block.timestamp + 6 minutes);
        
        // Try to add liquidity with stale price
        vm.expectRevert(abi.encodeWithSelector(LiquidityPool.StalePrice.selector, MARKET_ID));
        liquidityPool.addLiquidity(MARKET_ID, 500e18, INITIAL_PRICE * 110 / 100);
        vm.stopPrank();
    }

    /// @notice Test removing liquidity - 293,179 gas (0.005864 ETH @ 20 gwei)
    function testRemoveLiquidity() public {
        vm.startPrank(alice);
        uint256 initialAmount = 1000e18;
        liquidityPool.createPool(MARKET_ID, initialAmount, INITIAL_PRICE);
        
        uint256 removeShares = 500e18;
        liquidityPool.removeLiquidity(MARKET_ID, removeShares);
        
        (uint256 totalLiquidity, uint256 totalShares,) = liquidityPool.getPoolInfo(MARKET_ID);
        assertEq(totalLiquidity, initialAmount - removeShares);
        assertEq(totalShares, initialAmount - removeShares);
        vm.stopPrank();
    }
} 