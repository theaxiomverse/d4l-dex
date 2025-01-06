// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IOracle {
    function getOutcome(uint256 marketId) external view returns (uint256);
} 