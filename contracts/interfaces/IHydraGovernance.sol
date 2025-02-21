// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IHydraGovernance {
    function hasRole(bytes32 role, address account) external view returns (bool);
} 