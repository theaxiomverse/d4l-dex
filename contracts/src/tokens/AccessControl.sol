// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Auth, Authority} from "solmate/auth/Auth.sol";

contract AccessControl is Auth {
    // Role management
    mapping(bytes32 => mapping(address => bool)) private roles;
    mapping(address => bool) public blacklisted;
    mapping(bytes32 => mapping(address => uint256)) private pendingRoleChanges;
    
    // Emergency controls
    bool public stopped;
    uint256 public constant SECURITY_DELAY = 2 days;
    
    // Events
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);
    event BlacklistUpdated(address indexed account, bool blacklisted);
    event EmergencyAction(bool stopped);
    event RoleChangeInitiated(bytes32 indexed role, address indexed account);
    event RoleChangeExecuted(bytes32 indexed role, address indexed account);
    
    // Custom errors
    error Unauthorized(address account, bytes32 role);
    error Blacklisted(address account);
    error EmergencyStopped();
    error SecurityDelayNotMet();
    error AlreadyInitiated();
    
    // Modifiers
    modifier whenNotStopped() {
        if (stopped) revert EmergencyStopped();
        _;
    }
    
    modifier notBlacklisted(address account) {
        if (blacklisted[account]) revert Blacklisted(account);
        _;
    }
    
    modifier onlyRole(bytes32 role) {
        if (!hasRole(role, msg.sender)) revert Unauthorized(msg.sender, role);
        _;
    }
    
    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {
        // Grant admin role to owner
        _grantRole(keccak256("ADMIN_ROLE"), _owner);
    }
    
    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roles[role][account];
    }
    
    function grantRole(bytes32 role, address account) 
        external 
        requiresAuth 
        whenNotStopped 
        notBlacklisted(account) 
    {
        _grantRole(role, account);
    }
    
    function revokeRole(bytes32 role, address account) 
        external 
        requiresAuth 
        whenNotStopped 
    {
        _revokeRole(role, account);
    }
    
    function addToBlacklist(address account) 
        external 
        requiresAuth 
        whenNotStopped 
    {
        blacklisted[account] = true;
        emit BlacklistUpdated(account, true);
    }
    
    function removeFromBlacklist(address account) 
        external 
        requiresAuth 
        whenNotStopped 
    {
        blacklisted[account] = false;
        emit BlacklistUpdated(account, false);
    }
    
    function emergencyStop() 
        external 
        requiresAuth 
    {
        stopped = true;
        emit EmergencyAction(true);
    }
    
    function resumeOperation() 
        external 
        requiresAuth 
    {
        stopped = false;
        emit EmergencyAction(false);
    }
    
    function initiateRoleChange(bytes32 role, address account) 
        external 
        requiresAuth 
        whenNotStopped 
        notBlacklisted(account) 
    {
        if (pendingRoleChanges[role][account] != 0) revert AlreadyInitiated();
        pendingRoleChanges[role][account] = block.timestamp;
        emit RoleChangeInitiated(role, account);
    }
    
    function executeRoleChange(bytes32 role, address account) 
        external 
        requiresAuth 
        whenNotStopped 
        notBlacklisted(account) 
    {
        uint256 initiationTime = pendingRoleChanges[role][account];
        if (block.timestamp < initiationTime + SECURITY_DELAY) {
            revert SecurityDelayNotMet();
        }
        
        _grantRole(role, account);
        pendingRoleChanges[role][account] = 0;
        emit RoleChangeExecuted(role, account);
    }
    
    function _grantRole(bytes32 role, address account) internal {
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }
    
    function _revokeRole(bytes32 role, address account) internal {
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }
} 