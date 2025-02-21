// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/IUniswapV2Router02.sol";
import "../../../interfaces/IUniswapV2Factory.sol";
import "../../../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Router is IUniswapV2Router02 {
    address private immutable _factory;
    address private immutable _WETH;
    
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }
    
    constructor(address factory_, address WETH_) {
        require(factory_ != address(0), "Invalid factory address");
        require(WETH_ != address(0), "Invalid WETH address");
        _factory = factory_;
        _WETH = WETH_;
    }

    function factory() external view override returns (address) {
        return _factory;
    }

    function WETH() external view override returns (address) {
        return _WETH;
    }
    
    // View functions
    function quote(uint amountA, uint /* reserveA */, uint /* reserveB */) public pure override returns (uint amountB) {
        return amountA;
    }
    
    function getAmountOut(uint amountIn, uint /* reserveIn */, uint /* reserveOut */) public pure override returns (uint amountOut) {
        return amountIn;
    }
    
    function getAmountIn(uint amountOut, uint /* reserveIn */, uint /* reserveOut */) public pure override returns (uint amountIn) {
        return amountOut;
    }
    
    function getAmountsOut(uint amountIn, address[] calldata path) public pure override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = amountIn;
        }
        return amounts;
    }
    
    function getAmountsIn(uint amountOut, address[] calldata path) public pure override returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountOut;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = amountOut;
        }
        return amounts;
    }
    
    // Liquidity functions
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint /* amountAMin */,
        uint /* amountBMin */,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient");
        
        // Create pair if it doesn't exist
        address pair = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(_factory).createPair(tokenA, tokenB);
        }
        
        // Mock successful liquidity addition
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = 1e18;
        
        // Simulate token transfers
        IERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        
        // Mint LP tokens
        IUniswapV2Pair(pair).mint(to);
        
        return (amountA, amountB, liquidity);
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint /* amountTokenMin */,
        uint /* amountETHMin */,
        address to,
        uint deadline
    ) public override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient");
        require(msg.value > 0, "No ETH sent");
        
        // Create pair if it doesn't exist
        address pair = IUniswapV2Factory(_factory).getPair(token, _WETH);
        if (pair == address(0)) {
            pair = IUniswapV2Factory(_factory).createPair(token, _WETH);
        }
        
        // Mock successful liquidity addition
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 1e18;
        
        // Simulate token transfer
        IERC20(token).transferFrom(msg.sender, pair, amountToken);
        
        // Mint LP tokens
        IUniswapV2Pair(pair).mint(to);
        
        return (amountToken, amountETH, liquidity);
    }
    
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint /* amountAMin */,
        uint /* amountBMin */,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountA, uint amountB) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient");
        
        address pair = IUniswapV2Factory(_factory).getPair(tokenA, tokenB);
        require(pair != address(0), "Pair does not exist");
        
        // Mock removal amounts
        amountA = liquidity;
        amountB = liquidity;
        
        // Burn LP tokens
        IUniswapV2Pair(pair).burn(msg.sender);
        
        // Transfer tokens to recipient
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
        
        return (amountA, amountB);
    }
    
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint /* amountTokenMin */,
        uint /* amountETHMin */,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountToken, uint amountETH) {
        require(token != address(0), "Invalid token address");
        require(to != address(0), "Invalid recipient");
        
        address pair = IUniswapV2Factory(_factory).getPair(token, _WETH);
        require(pair != address(0), "Pair does not exist");
        
        // Mock removal amounts
        amountToken = liquidity;
        amountETH = liquidity;
        
        // Burn LP tokens
        IUniswapV2Pair(pair).burn(msg.sender);
        
        // Transfer tokens to recipient
        IERC20(token).transfer(to, amountToken);
        payable(to).transfer(amountETH);
        
        return (amountToken, amountETH);
    }
    
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool /* approveMax */,
        uint8 /* v */,
        bytes32 /* r */,
        bytes32 /* s */
    ) external override returns (uint amountA, uint amountB) {
        return removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool /* approveMax */,
        uint8 /* v */,
        bytes32 /* r */,
        bytes32 /* s */
    ) external override returns (uint amountToken, uint amountETH) {
        return removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }
    
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint /* amountTokenMin */,
        uint /* amountETHMin */,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            0, // amountTokenMin
            0, // amountETHMin
            to,
            deadline
        );
    }
    
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool /* approveMax */,
        uint8 /* v */,
        bytes32 /* r */,
        bytes32 /* s */
    ) external override returns (uint amountETH) {
        return removeLiquidityETHSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = amountIn;
        }
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[path.length - 1]).transfer(to, amounts[path.length - 1]);
        
        return amounts;
    }
    
    function swapTokensForExactTokens(
        uint amountOut,
        uint /* amountInMax */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = new uint[](path.length);
        for(uint i = 0; i < path.length; i++) {
            amounts[i] = amountOut;
        }
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]);
        IERC20(path[path.length - 1]).transfer(to, amountOut);
        
        return amounts;
    }
    
    function swapExactETHForTokens(
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(path[0] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = msg.value;
        }
        
        // Transfer tokens
        IERC20(path[path.length - 1]).transfer(to, amounts[path.length - 1]);
        
        return amounts;
    }
    
    function swapTokensForExactETH(
        uint amountOut,
        uint /* amountInMax */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(path[path.length - 1] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = new uint[](path.length);
        for(uint i = 0; i < path.length; i++) {
            amounts[i] = amountOut;
        }
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]);
        payable(to).transfer(amountOut);
        
        return amounts;
    }
    
    function swapExactTokensForETH(
        uint amountIn,
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(path[path.length - 1] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for(uint i = 1; i < path.length; i++) {
            amounts[i] = amountIn;
        }
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        payable(to).transfer(amounts[path.length - 1]);
        
        return amounts;
    }
    
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(path[0] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        require(msg.value >= amountOut, "Insufficient ETH sent");
        
        amounts = new uint[](path.length);
        for(uint i = 0; i < path.length; i++) {
            amounts[i] = amountOut;
        }
        
        // Transfer tokens
        IERC20(path[path.length - 1]).transfer(to, amountOut);
        
        // Refund excess ETH
        if (msg.value > amountOut) {
            payable(msg.sender).transfer(msg.value - amountOut);
        }
        
        return amounts;
    }
    
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        require(path.length >= 2, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[path.length - 1]).transfer(to, amountIn);
    }
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override payable ensure(deadline) {
        require(path.length >= 2, "Invalid path");
        require(path[0] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        // Transfer tokens
        IERC20(path[path.length - 1]).transfer(to, msg.value);
    }
    
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint /* amountOutMin */,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        require(path.length >= 2, "Invalid path");
        require(path[path.length - 1] == _WETH, "Invalid path");
        require(to != address(0), "Invalid recipient");
        
        // Transfer tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        payable(to).transfer(amountIn);
    }
    
    receive() external payable {
        // Accept ETH transfers
    }
} 