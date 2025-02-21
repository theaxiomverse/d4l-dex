// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDexPausable {
    function pause() external;
    function unpause() external;
} 