// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "../tokens/AccessControl.sol";
import "../interfaces/IPriceOracle.sol";

contract PriceOracle is AccessControl, IPriceOracle {
    // Role constants
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // Price data
    mapping(uint256 => uint256) public prices;
    mapping(uint256 => uint256) public lastUpdateTimes;
    
    // Price validity window
    uint256 public constant PRICE_VALIDITY = 5 minutes;
    
    // Events
    event PriceUpdated(uint256 indexed marketId, uint256 price, uint256 timestamp);
    
    // Custom errors
    error PriceStale(uint256 marketId);
    error InvalidPrice(uint256 price);
    error InvalidMarket(uint256 marketId);
    
    constructor(address _owner, Authority _authority) AccessControl(_owner, _authority) {
        // Grant updater role to owner
        _grantRole(UPDATER_ROLE, _owner);
    }
    
    function getPrice(uint256 marketId) external view override returns (uint256) {
        uint256 price = prices[marketId];
        if (price == 0) revert InvalidMarket(marketId);
        
        uint256 lastUpdate = lastUpdateTimes[marketId];
        if (block.timestamp > lastUpdate + PRICE_VALIDITY) {
            revert PriceStale(marketId);
        }
        
        return price;
    }
    
    function updatePrice(uint256 marketId, uint256 newPrice) 
        external 
        override 
        whenNotStopped 
        notBlacklisted(msg.sender)
        onlyRole(UPDATER_ROLE)
    {
        if (newPrice == 0) revert InvalidPrice(newPrice);
        
        prices[marketId] = newPrice;
        lastUpdateTimes[marketId] = block.timestamp;
        
        emit PriceUpdated(marketId, newPrice, block.timestamp);
    }
} 