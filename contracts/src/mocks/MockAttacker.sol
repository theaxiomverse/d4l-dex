// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../tokens/AccessControl.sol";

contract MockAttacker {
    function attemptRoleElevation(address _target) external {
        // Try to gain admin role through various attack vectors
        AccessControl ac = AccessControl(_target);
        
        // Direct role grant attempt
        bytes32 adminRole = keccak256("ADMIN_ROLE");
        ac.grantRole(adminRole, address(this));
    }
} 