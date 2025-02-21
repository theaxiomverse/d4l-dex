// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/IUniswapV2Factory.sol";
import "../../../interfaces/IUniswapV2Pair.sol";
import "./MockUniswapV2Pair.sol";

contract MockUniswapV2Factory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;
    
    constructor() {
        feeToSetter = msg.sender;
    }
    
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        
        // Deploy a new mock pair contract
        bytes memory bytecode = type(MockUniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize the pair
        MockUniswapV2Pair(pair).initialize(token0, token1);
        
        // Store the pair
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }
    
    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
} 