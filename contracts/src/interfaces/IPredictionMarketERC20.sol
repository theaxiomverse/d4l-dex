// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./IERC20.sol";

interface IPredictionMarketERC20 is IERC20 {
    function freezeAccount(address account, bool freeze) external;
    function isAccountFrozen(address account) external view returns (bool);
    function createMarket(string calldata question, string[] calldata outcomes) external returns (uint256 marketId);
    function placeBet(uint256 marketId, uint256 outcomeIndex, uint256 amount) external returns (bool);
    function resolveMarket(uint256 marketId) external returns (bool);
    function withdrawWinnings(uint256 marketId) external returns (bool);
} 