// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/tokens/FoundersVesting.sol";
import "../src/mocks/MockERC20.sol";
import {Authority} from "solmate/auth/Auth.sol";

/**
 * @title FoundersVesting Test
 * @notice Test suite for the FoundersVesting contract
 * @dev Test coverage includes:
 * - Vesting schedule creation
 * - Token claiming after cliff
 * - Linear vesting calculation
 * - Emergency controls
 * - Revocation of vesting
 * 
 * Key properties:
 * - Total claimed amount must be <= Total vested amount
 * - Vested amount is 0 before cliff
 * - Vested amount equals totalAmount after vestingEnd
 * - Claims are blocked during pause
 */
contract FoundersVestingTest is Test {
    FoundersVesting public vesting;
    MockERC20 public token;
    
    address public constant FOUNDER = address(0x2);
    uint256 public constant TOTAL_AMOUNT = 100_000e18;
    uint256 public constant CLIFF_DURATION = 365 days;
    uint256 public constant VESTING_DURATION = 1460 days;
    
    function setUp() public {
        token = new MockERC20("Test Token", "TEST", 18);
        vesting = new FoundersVesting(address(token), address(this), Authority(address(0)));
        
        // Mint tokens to this contract
        token.mint(address(this), TOTAL_AMOUNT);
        token.approve(address(vesting), TOTAL_AMOUNT);
        
        // Create vesting schedule for founder
        vesting.createVestingSchedule(
            FOUNDER,
            TOTAL_AMOUNT,
            true
        );
        
        // Transfer tokens to vesting contract
        token.transfer(address(vesting), TOTAL_AMOUNT);
    }
    
    function testInitialSetup() public {
        (
            uint256 totalAmount,
            uint256 claimedAmount,
            uint256 startTime,
            uint256 cliffEnd,
            uint256 vestingEnd,
            bool isActive,
            bool isRevocable
        ) = vesting.vestingSchedules(FOUNDER);
        
        assertEq(totalAmount, TOTAL_AMOUNT);
        assertEq(claimedAmount, 0);
        assertEq(cliffEnd, block.timestamp + CLIFF_DURATION);
        assertEq(vestingEnd, block.timestamp + VESTING_DURATION);
        assertTrue(isActive);
        assertTrue(isRevocable);
    }
    
    function testVestingBeforeCliff() public {
        uint256 vestedAmount = vesting.calculateVestedAmount(FOUNDER);
        assertEq(vestedAmount, 0);
    }
    
    function testVestingAfterCliff() public {
        // Move to halfway between cliff and vesting end
        vm.warp(block.timestamp + CLIFF_DURATION + (VESTING_DURATION - CLIFF_DURATION) / 2);
        
        uint256 vestedAmount = vesting.calculateVestedAmount(FOUNDER);
        uint256 expectedAmount = TOTAL_AMOUNT / 2; // Should be 50% vested
        
        assertApproxEqRel(vestedAmount, expectedAmount, 0.01e18); // Allow 1% deviation
    }
    
    function testClaimTokens() public {
        // Move to halfway point
        vm.warp(block.timestamp + CLIFF_DURATION + (VESTING_DURATION - CLIFF_DURATION) / 2);
        
        uint256 expectedAmount = TOTAL_AMOUNT / 2;
        
        vm.prank(FOUNDER);
        vesting.claimVestedTokens();
        
        assertApproxEqRel(token.balanceOf(FOUNDER), expectedAmount, 0.01e18);
    }
    
    function testRevokeVesting() public {
        vm.warp(block.timestamp + CLIFF_DURATION + 1);
        
        vesting.revokeVesting(FOUNDER);
        
        (,,,,, bool isActive,) = vesting.vestingSchedules(FOUNDER);
        assertFalse(isActive);
    }
    
    function testEmergencyPause() public {
        // Move to halfway point so there are tokens to claim
        vm.warp(block.timestamp + CLIFF_DURATION + (VESTING_DURATION - CLIFF_DURATION) / 2);
        
        // Initiate and execute emergency pause
        bytes32 pauseAction = bytes32("PAUSE");
        vesting.initiateEmergencyAction(pauseAction);
        vm.warp(block.timestamp + 7 days);
        vesting.executeEmergencyAction(pauseAction);
        
        // Try to claim during pause
        vm.prank(FOUNDER);
        vm.expectRevert(FoundersVesting.ContractPaused.selector);
        vesting.claimVestedTokens();
        
        // Resume operations
        bytes32 unpauseAction = bytes32("UNPAUSE");
        vesting.initiateEmergencyAction(unpauseAction);
        vm.warp(block.timestamp + 7 days);
        vesting.executeEmergencyAction(unpauseAction);
        
        // Should be able to claim now
        vm.prank(FOUNDER);
        vesting.claimVestedTokens();
        
        // Verify tokens were received
        assertGt(token.balanceOf(FOUNDER), 0);
    }
    
    function testFullVestingPeriod() public {
        // Move past vesting end
        vm.warp(block.timestamp + VESTING_DURATION + 1);
        
        uint256 vestedAmount = vesting.calculateVestedAmount(FOUNDER);
        assertApproxEqRel(vestedAmount, TOTAL_AMOUNT, 0.01e18); // Allow 1% deviation
    }
} 