// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/ITokenomics.sol";

contract MockTokenomics is ITokenomics {
    function calculateTax(uint256 amount) external pure returns (uint256) {
        return amount * 3 / 100; // 3% tax
    }

    function calculateBurn(uint256 amount) external pure returns (uint256) {
        return amount * 1 / 100; // 1% burn
    }

    function calculateCommunityWallet(uint256 amount) external pure returns (uint256) {
        return amount * 25 / 1000; // 2.5% community
    }

    function calculateTeamWallet(uint256 amount) external pure returns (uint256) {
        return amount * 20 / 1000; // 2% team
    }

    function calculateDEXLiquidity(uint256 amount) external pure returns (uint256) {
        return amount * 30 / 1000; // 3% DEX liquidity
    }

    function calculateTreasuryInitiative(uint256 amount) external pure returns (uint256) {
        return amount * 10 / 1000; // 1% treasury
    }

    function calculateMarketingWallet(uint256 amount) external pure returns (uint256) {
        return amount * 10 / 1000; // 1% marketing
    }

    function calculateCEXLiquidity(uint256 amount) external pure returns (uint256) {
        return amount * 5 / 1000; // 0.5% CEX liquidity
    }

    function calculateTotal(uint256 amount) external pure returns (uint256) {
        return amount * 4 / 100; // 4% total (3% tax + 1% burn)
    }

    function calculateTotalFees(uint256 amount) external pure returns (uint256) {
        return amount * 3 / 100; // 3% total fees
    }
} 