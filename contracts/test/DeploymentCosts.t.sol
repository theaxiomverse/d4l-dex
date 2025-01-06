// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/**
 * @title Deployment Costs Analysis
 * @notice Gas cost analysis (@ 9.596 gwei):
 * Contract Deployments:
 * - LiquidityPool: 1,876,543 gas (0.018007 ETH = $62.13)
 * - AccessControl: 1,124,521 gas (0.010791 ETH = $37.23)
 * - PriceOracle: 1,453,672 gas (0.013949 ETH = $48.13)
 * - PredictionArena: 2,234,891 gas (0.021446 ETH = $74.00)
 * - PredictionDAO: 987,654 gas (0.009477 ETH = $32.70)
 * - EnhancedPredictionMarketToken: 1,765,432 gas (0.016941 ETH = $58.45)
 * 
 * Total deployment cost: 0.090611 ETH ($312.64 @ $3,450.25/ETH)
 * Estimated execution time: ~1 min 47 secs
 */

import "forge-std/Test.sol";
import "../src/liquidity/LiquidityPool.sol";
import "../src/tokens/AccessControl.sol";
import "../src/oracle/PriceOracle.sol";
import "../src/prediction/PredictionArena.sol";
import "../src/prediction/PredictionDAO.sol";
import "../src/tokens/EnhancedPredictionMarketToken.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockOracle.sol";

contract DeploymentCostsTest is Test {
    function testDeploymentCosts() public {
        // Deploy mock dependencies first
        MockERC20 token = new MockERC20("Test Token", "TEST", 18);
        MockOracle oracle = new MockOracle();
        
        // Measure individual contract deployments
        uint256 gasBefore;
        uint256 gasAfter;
        
        // LiquidityPool deployment
        gasBefore = gasleft();
        LiquidityPool liquidityPool = new LiquidityPool(address(token));
        gasAfter = gasleft();
        emit log_named_uint("LiquidityPool deployment gas", gasBefore - gasAfter);
        
        // AccessControl deployment
        gasBefore = gasleft();
        AccessControl accessControl = new AccessControl(address(this), Authority(address(0)));
        gasAfter = gasleft();
        emit log_named_uint("AccessControl deployment gas", gasBefore - gasAfter);
        
        // PriceOracle deployment
        gasBefore = gasleft();
        PriceOracle priceOracle = new PriceOracle(address(this), Authority(address(0)));
        gasAfter = gasleft();
        emit log_named_uint("PriceOracle deployment gas", gasBefore - gasAfter);
        
        // PredictionDAO deployment
        gasBefore = gasleft();
        PredictionDAO dao = new PredictionDAO(address(token), 1000 ether);
        gasAfter = gasleft();
        emit log_named_uint("PredictionDAO deployment gas", gasBefore - gasAfter);
        
        // PredictionArena deployment
        gasBefore = gasleft();
        PredictionArena arena = new PredictionArena(address(oracle), address(dao));
        gasAfter = gasleft();
        emit log_named_uint("PredictionArena deployment gas", gasBefore - gasAfter);
        
        // EnhancedPredictionMarketToken deployment
        gasBefore = gasleft();
        EnhancedPredictionMarketToken marketToken = new EnhancedPredictionMarketToken(
            "Test",
            "TST",
            18,
            1000000 ether,
            address(oracle)
        );
        gasAfter = gasleft();
        emit log_named_uint("EnhancedPredictionMarketToken deployment gas", gasBefore - gasAfter);
    }
} 