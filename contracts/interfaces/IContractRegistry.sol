// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IContractRegistry {
    function getContractAddress(string memory name) external view returns (address);
    function getContractAddress(bytes32 key) external view returns (address);
} 