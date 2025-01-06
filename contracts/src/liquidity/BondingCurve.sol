// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract BondingCurve is Auth {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    struct CurveParams {
        uint256 basePrice;      // Starting price in ETH
        uint256 slope;          // Price increase per token (in basis points)
        uint256 maxPrice;       // Maximum price cap
        uint256 minPrice;       // Minimum price floor
    }

    struct PoolState {
        uint256 tokenBalance;   // Current token balance
        uint256 ethBalance;     // Current ETH balance
        uint256 lastPrice;      // Last trade price
    }

    ERC20 public immutable token;
    uint256 public immutable INITIAL_SUPPLY;
    
    // Curve parameters
    CurveParams public curveParams;
    PoolState public poolState;
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_PURCHASE = 0.01 ether;

    // Events
    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event TokensSold(address indexed seller, uint256 tokenAmount, uint256 ethAmount);
    event PoolStateUpdated(uint256 tokenBalance, uint256 ethBalance, uint256 price);

    // Custom errors
    error SlippageExceeded();
    error InvalidAmount();
    error PriceOutOfBounds();
    error InsufficientLiquidity();

    constructor(
        address _token,
        address _owner,
        Authority _authority,
        uint256 basePrice,
        uint256 slope
    ) Auth(_owner, _authority) {
        token = ERC20(_token);
        INITIAL_SUPPLY = token.totalSupply();
        
        curveParams = CurveParams({
            basePrice: basePrice,
            slope: slope,
            maxPrice: basePrice * 10,
            minPrice: basePrice / 10
        });

        poolState = PoolState({
            tokenBalance: 0,
            ethBalance: 0,
            lastPrice: basePrice
        });
    }

    function calculateBuyPrice(uint256 ethAmount) public view returns (uint256 price) {
        if (ethAmount == 0) revert InvalidAmount();
        
        // Simple linear price increase based on ETH amount relative to pool
        price = curveParams.basePrice + ((ethAmount * curveParams.slope) / 1e18);
        
        if (price > curveParams.maxPrice) revert PriceOutOfBounds();
        if (price < curveParams.minPrice) revert PriceOutOfBounds();
        
        return price;
    }

    function calculateSellPrice(uint256 tokenAmount) public view returns (uint256 price) {
        if (tokenAmount == 0) revert InvalidAmount();
        if (tokenAmount > poolState.tokenBalance) revert InsufficientLiquidity();
        
        // Simple linear price decrease based on token amount
        price = curveParams.basePrice - ((tokenAmount * curveParams.slope) / 1e18);
        
        if (price < curveParams.minPrice) revert PriceOutOfBounds();
        if (price > curveParams.maxPrice) revert PriceOutOfBounds();
        
        return price;
    }

    function buyTokens(uint256 minTokens) external payable returns (uint256 tokenAmount) {
        if (msg.value < MIN_PURCHASE) revert InvalidAmount();
        
        uint256 initialTokenBalance = token.balanceOf(address(this));
        if (initialTokenBalance == 0) revert InsufficientLiquidity();
        
        // Calculate token amount based on current price
        uint256 price = calculateBuyPrice(msg.value);
        tokenAmount = msg.value.mulWadDown(1e18).divWadDown(price);
        
        if (tokenAmount < minTokens) revert SlippageExceeded();
        if (tokenAmount > initialTokenBalance) revert InsufficientLiquidity();
        
        // Update state
        poolState.tokenBalance = initialTokenBalance - tokenAmount;
        poolState.ethBalance += msg.value;
        poolState.lastPrice = price;
        
        // Transfer tokens
        token.safeTransfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
        emit PoolStateUpdated(poolState.tokenBalance, poolState.ethBalance, price);
    }

    function sellTokens(uint256 tokenAmount, uint256 minEthAmount) external returns (uint256 ethAmount) {
        if (tokenAmount == 0) revert InvalidAmount();
        
        uint256 initialEthBalance = address(this).balance;
        if (initialEthBalance == 0) revert InsufficientLiquidity();
        
        // Calculate ETH amount based on current price
        uint256 price = calculateSellPrice(tokenAmount);
        ethAmount = tokenAmount.mulWadDown(price).divWadDown(1e18);
        
        if (ethAmount < minEthAmount) revert SlippageExceeded();
        if (ethAmount > initialEthBalance) revert InsufficientLiquidity();
        
        // Update state
        poolState.tokenBalance = token.balanceOf(address(this)) + tokenAmount;
        poolState.ethBalance = initialEthBalance - ethAmount;
        poolState.lastPrice = price;
        
        // Transfer tokens first (checks-effects-interactions pattern)
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        SafeTransferLib.safeTransferETH(msg.sender, ethAmount);
        
        emit TokensSold(msg.sender, tokenAmount, ethAmount);
        emit PoolStateUpdated(poolState.tokenBalance, poolState.ethBalance, price);
    }

    function updatePoolState(
        uint256 tokenBalance,
        uint256 ethBalance,
        uint256 price
    ) external requiresAuth {
        if (price == 0) revert InvalidAmount();
        if (price < curveParams.minPrice || price > curveParams.maxPrice) revert PriceOutOfBounds();
        
        poolState.tokenBalance = tokenBalance;
        poolState.ethBalance = ethBalance;
        poolState.lastPrice = price;
        
        emit PoolStateUpdated(tokenBalance, ethBalance, price);
    }

    receive() external payable {}
} 