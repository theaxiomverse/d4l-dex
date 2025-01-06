// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/liquidity/LiquidityPool.sol";
import "../src/tokens/EnhancedPredictionMarketToken.sol";
import "../src/oracle/PriceOracle.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        PredictionMarketERC20 token = new PredictionMarketERC20(
            "Prediction Token",
            "PRED",
            18,
            address(this), // owner
            1000); // initial pool size
        LiquidityPool liquidityPool = new LiquidityPool(
            address(token)
        );

        PriceOracle priceOracle = new PriceOracle();

        token.approve(address(liquidityPool), type(uint256).max);

        uint256 initialLiquidity = 1000 * 1e18;
        uint256 initialPrice = 1e18;
        liquidityPool.createPool(1, initialLiquidity, initialPrice);


        console.log("Deployed contracts:");
        console.log("Token:", address(token));
        console.log("LiquidityPool:", address(liquidityPool)); 
        console.log("PriceOracle:", address(priceOracle));
        // Log the addresses
        console.log("CandidateToken deployed to:", address(candidateToken));
        console.log("BondingCurve deployed to:", address(bondingCurve));

        vm.stopBroadcast();
    }
} 
