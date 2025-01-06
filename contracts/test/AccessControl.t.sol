// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "../src/tokens/AccessControl.sol";
import "../src/mocks/MockAttacker.sol";
import {Authority} from "solmate/auth/Auth.sol";

contract AccessControlTest is Test {
    AccessControl public accessControl;
    MockAttacker public attacker;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    function setUp() public {
        accessControl = new AccessControl(address(this), Authority(address(0)));
        attacker = new MockAttacker();
        
        // Grant initial roles
        accessControl.grantRole(ADMIN_ROLE, address(this));
        accessControl.grantRole(OPERATOR_ROLE, address(this));
    }
    
    function testInitialAdminRole() public {
        assertTrue(accessControl.hasRole(ADMIN_ROLE, address(this)));
    }
    
    function testGrantRole() public {
        address user = address(0x1);
        accessControl.grantRole(OPERATOR_ROLE, user);
        assertTrue(accessControl.hasRole(OPERATOR_ROLE, user));
    }
    
    function testRevokeRole() public {
        address user = address(0x1);
        accessControl.grantRole(OPERATOR_ROLE, user);
        accessControl.revokeRole(OPERATOR_ROLE, user);
        assertFalse(accessControl.hasRole(OPERATOR_ROLE, user));
    }
    
    function testBlacklist() public {
        address malicious = address(0x1);
        accessControl.addToBlacklist(malicious);
        assertTrue(accessControl.blacklisted(malicious));
        
        vm.prank(malicious);
        vm.expectRevert();
        accessControl.grantRole(OPERATOR_ROLE, malicious);
    }
    
    function testEmergencyStop() public {
        accessControl.emergencyStop();
        assertTrue(accessControl.stopped());
        
        vm.expectRevert();
        accessControl.grantRole(OPERATOR_ROLE, address(0x1));
        
        accessControl.resumeOperation();
        assertFalse(accessControl.stopped());
    }
    
    function testSecurityDelay() public {
        address newOperator = address(0x1);
        
        // Initiate role change
        accessControl.initiateRoleChange(OPERATOR_ROLE, newOperator);
        
        // Try to execute immediately - should fail
        vm.expectRevert(AccessControl.SecurityDelayNotMet.selector);
        accessControl.executeRoleChange(OPERATOR_ROLE, newOperator);
        
        // Wait for delay and execute
        vm.warp(block.timestamp + 3 days);
        accessControl.executeRoleChange(OPERATOR_ROLE, newOperator);
        
        // Verify role was granted
        assertTrue(accessControl.hasRole(OPERATOR_ROLE, newOperator));
    }
    
    function testAttackRoleElevation() public {
        // Try to elevate attacker to admin role
        vm.expectRevert("UNAUTHORIZED");
        attacker.attemptRoleElevation(address(accessControl));
        
        // Verify attacker does not have admin role
        assertFalse(accessControl.hasRole(ADMIN_ROLE, address(attacker)));
    }
} 