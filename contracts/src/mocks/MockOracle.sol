// src/common/MockOracle.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract MockOracle {
    mapping(uint256 => uint256) public outcomes;

    function setOutcome(uint256 marketId, uint256 outcomeIndex) external {
        outcomes[marketId] = outcomeIndex;
    }

    function getOutcome(uint256 marketId) external view returns (uint256) {
        return outcomes[marketId];
    }
}