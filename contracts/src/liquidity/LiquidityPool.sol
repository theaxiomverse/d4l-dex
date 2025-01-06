// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC20 as SolmateERC20} from "solmate/tokens/ERC20.sol";
import {Authority} from "solmate/auth/Auth.sol";
import "solmate/auth/Auth.sol";
import "solmate/utils/ReentrancyGuard.sol";

contract LiquidityPool is Auth, ReentrancyGuard {
    struct Pool {
        uint256 totalLiquidity;
        mapping(address => uint256) shares;
        uint256 totalShares;
        bool active;
        uint256 marketId;
        uint256 lastPrice;        // Last recorded price
        uint256 lastUpdateTime;   // Last price update timestamp
    }

    mapping(uint256 => Pool) public pools; // marketId => Pool
    SolmateERC20 public immutable token;
    
    uint256 public constant MIN_LIQUIDITY = 1e18; // 1 token minimum
    uint256 public constant LIQUIDITY_FEE = 3; // 0.3% fee
    uint256 public constant MAX_PRICE_CHANGE = 50; // 50% max price change
    uint256 public constant PRICE_VALIDITY_PERIOD = 5 minutes;
    
    event PoolCreated(uint256 indexed marketId);
    event LiquidityAdded(uint256 indexed marketId, address indexed provider, uint256 amount, uint256 shares);
    event LiquidityRemoved(uint256 indexed marketId, address indexed provider, uint256 amount, uint256 shares);
    event PriceUpdated(uint256 indexed marketId, uint256 price, uint256 timestamp);
    event AnomalyDetected(uint256 indexed marketId, uint256 oldPrice, uint256 newPrice);
    
    error PriceChangeTooBig(uint256 oldPrice, uint256 newPrice);
    error StalePrice(uint256 marketId);
    error InvalidPrice(uint256 price);
    
    constructor(address _token) Auth(msg.sender, Authority(address(0))) {
        token = SolmateERC20(_token);
    }

    function _calculatePriceChange(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (newPrice > oldPrice) {
            return ((newPrice - oldPrice) * 100) / oldPrice;
        }
        return ((oldPrice - newPrice) * 100) / oldPrice;
    }
    
    function _validatePrice(uint256 marketId, uint256 newPrice) internal {
        Pool storage pool = pools[marketId];
        if (pool.lastPrice > 0) {
            if (block.timestamp > pool.lastUpdateTime + PRICE_VALIDITY_PERIOD) {
                revert StalePrice(marketId);
            }
            uint256 priceChange = _calculatePriceChange(pool.lastPrice, newPrice);
            if (priceChange > MAX_PRICE_CHANGE) {
                emit AnomalyDetected(marketId, pool.lastPrice, newPrice);
                revert PriceChangeTooBig(pool.lastPrice, newPrice);
            }
        }
    }
    
    function createPool(uint256 marketId, uint256 initialLiquidity, uint256 initialPrice) external requiresAuth nonReentrant {
        require(!pools[marketId].active, "Pool already exists");
        require(initialLiquidity >= MIN_LIQUIDITY, "Insufficient initial liquidity");
        require(initialPrice > 0, "Invalid initial price");
        
        Pool storage pool = pools[marketId];
        pool.active = true;
        pool.marketId = marketId;
        pool.lastPrice = initialPrice;
        pool.lastUpdateTime = block.timestamp;
        
        require(token.transferFrom(msg.sender, address(this), initialLiquidity), "Transfer failed");
        
        // Initial shares are equal to initial liquidity
        pool.totalLiquidity = initialLiquidity;
        pool.shares[msg.sender] = initialLiquidity;
        pool.totalShares = initialLiquidity;
        
        emit PoolCreated(marketId);
        emit LiquidityAdded(marketId, msg.sender, initialLiquidity, initialLiquidity);
        emit PriceUpdated(marketId, initialPrice, block.timestamp);
    }
    
    function addLiquidity(uint256 marketId, uint256 amount, uint256 currentPrice) external nonReentrant {
        Pool storage pool = pools[marketId];
        require(pool.active, "Pool does not exist");
        require(amount > 0, "Amount must be positive");
        
        _validatePrice(marketId, currentPrice);
        
        uint256 newShares = (amount * pool.totalShares) / pool.totalLiquidity;
        require(newShares > 0, "Insufficient liquidity provided");
        
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        pool.totalLiquidity += amount;
        pool.shares[msg.sender] += newShares;
        pool.totalShares += newShares;
        pool.lastPrice = currentPrice;
        pool.lastUpdateTime = block.timestamp;
        
        emit LiquidityAdded(marketId, msg.sender, amount, newShares);
        emit PriceUpdated(marketId, currentPrice, block.timestamp);
    }
    
    function removeLiquidity(uint256 marketId, uint256 shares) external nonReentrant {
        Pool storage pool = pools[marketId];
        require(pool.active, "Pool does not exist");
        require(shares > 0 && shares <= pool.shares[msg.sender], "Invalid shares amount");
        
        uint256 amount = (shares * pool.totalLiquidity) / pool.totalShares;
        require(amount > 0, "Insufficient liquidity");
        
        pool.totalLiquidity -= amount;
        pool.shares[msg.sender] -= shares;
        pool.totalShares -= shares;
        
        require(token.transfer(msg.sender, amount), "Transfer failed");
        
        emit LiquidityRemoved(marketId, msg.sender, amount, shares);
    }
    
    function getPoolInfo(uint256 marketId) external view returns (
        uint256 totalLiquidity,
        uint256 totalShares,
        bool active
    ) {
        Pool storage pool = pools[marketId];
        return (pool.totalLiquidity, pool.totalShares, pool.active);
    }
    
    function getShares(uint256 marketId, address provider) external view returns (uint256) {
        return pools[marketId].shares[provider];
    }
} 