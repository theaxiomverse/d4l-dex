// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDegenENS {
    event NameRegistered(bytes32 indexed nameHash, address indexed owner, uint256 expiryTime);
    event NameTransferred(bytes32 indexed nameHash, address indexed oldOwner, address indexed newOwner);
    event ResolverUpdated(bytes32 indexed nameHash, address indexed resolver);
    event NameRenewed(bytes32 indexed nameHash, uint256 newExpiryTime);

    function registerName(
        string calldata name,
        address owner,
        uint256 duration
    ) external;

    function setResolver(
        bytes32 nameHash,
        address resolver
    ) external;

    function transferName(
        bytes32 nameHash,
        address newOwner
    ) external;

    function renewName(
        bytes32 nameHash,
        uint256 duration
    ) external;

    function resolve(bytes32 nameHash) external view returns (address);

    function getOwner(bytes32 nameHash) external view returns (address);

    function getResolver(bytes32 nameHash) external view returns (address);

    function getExpiryTime(bytes32 nameHash) external view returns (uint256);

    function isExpired(bytes32 nameHash) external view returns (bool);
} 