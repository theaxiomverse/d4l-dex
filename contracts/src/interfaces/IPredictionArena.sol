// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IPredictionArena {
    function createArena(
        string calldata name,
        uint256 duration,
        address yesToken,
        address noToken
    ) external payable returns (uint256 arenaId);

    function stakeYes(uint256 arenaId, uint256 amount) external;
    function stakeNo(uint256 arenaId, uint256 amount) external;
    function resolveArena(uint256 arenaId) external;
    function claimRewards(uint256 arenaId) external;
    
    function getTotalYesStakes(uint256 arenaId) external view returns (uint256);
    function getTotalNoStakes(uint256 arenaId) external view returns (uint256);
} 