// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IPriceOracle {
    function getPrice(uint256 marketId) external view returns (uint256);
    function updatePrice(uint256 marketId, uint256 price) external;
} 