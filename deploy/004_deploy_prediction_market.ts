import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("\nDeploying Prediction Market components...");

    try {
        // Get core contract addresses
        const registry = await get('ContractRegistry');
        const weth = await get('WETH9');

        // Deploy PredictionMarket
        console.log("\n1. Deploying PredictionMarket...");
        const predictionMarket = await deploy('DegenPredictionMarket', {
            from: deployer,
            contract: 'contracts/prediction/DegenPredictionMarket.sol:DegenPredictionMarket',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address, weth.address],
                },
            },
            log: true,
        });
        console.log("PredictionMarket deployed to:", predictionMarket.address);

        // Deploy MarketOracle
        console.log("\n2. Deploying MarketOracle...");
        const marketOracle = await deploy('MarketOracle', {
            from: deployer,
            contract: 'contracts/prediction/MarketOracle.sol:MarketOracle',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("MarketOracle deployed to:", marketOracle.address);

        // Deploy MarketMaker
        console.log("\n3. Deploying MarketMaker...");
        const marketMaker = await deploy('MarketMaker', {
            from: deployer,
            contract: 'contracts/prediction/MarketMaker.sol:MarketMaker',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [predictionMarket.address, weth.address],
                },
            },
            log: true,
        });
        console.log("MarketMaker deployed to:", marketMaker.address);

        // Register contracts in registry
        console.log("\nRegistering Prediction Market contracts in registry...");
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("PREDICTION_MARKET"),
            predictionMarket.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("MARKET_ORACLE"),
            marketOracle.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("MARKET_MAKER"),
            marketMaker.address
        );

        // Initialize Prediction Market components
        console.log("\nInitializing Prediction Market components...");
        
        // Set oracle in Prediction Market
        await execute(
            'DegenPredictionMarket',
            { from: deployer, log: true },
            'setOracle',
            marketOracle.address
        );

        // Set market maker in Prediction Market
        await execute(
            'DegenPredictionMarket',
            { from: deployer, log: true },
            'setMarketMaker',
            marketMaker.address
        );

        // Set initial parameters
        await execute(
            'DegenPredictionMarket',
            { from: deployer, log: true },
            'setParameters',
            {
                minBetAmount: ethers.parseEther("0.01"), // 0.01 ETH
                maxBetAmount: ethers.parseEther("100"), // 100 ETH
                minMarketDuration: 3600, // 1 hour
                maxMarketDuration: 7 * 24 * 3600, // 1 week
                resolutionWindow: 24 * 3600, // 1 day
                protocolFee: 300, // 3%
                creatorFee: 100, // 1%
                resolverFee: 100 // 1%
            }
        );

        // Set oracle parameters
        await execute(
            'MarketOracle',
            { from: deployer, log: true },
            'setParameters',
            {
                minValidators: 3,
                validationThreshold: 66, // 66%
                validationReward: ethers.parseEther("0.1"), // 0.1 ETH
                slashingPenalty: ethers.parseEther("1"), // 1 ETH
                validationWindow: 3600 // 1 hour
            }
        );

        // Set market maker parameters
        await execute(
            'MarketMaker',
            { from: deployer, log: true },
            'setParameters',
            {
                initialLiquidity: ethers.parseEther("10"), // 10 ETH
                minLiquidity: ethers.parseEther("1"), // 1 ETH
                maxLiquidity: ethers.parseEther("1000"), // 1000 ETH
                spreadMultiplier: 100, // 1%
                curveMultiplier: 200, // 2%
                dynamicFee: true
            }
        );

        console.log("\nPrediction Market deployment completed successfully!");

    } catch (error) {
        console.error("Prediction Market deployment failed:", error);
        throw error;
    }
};

func.tags = ['prediction-market'];
func.dependencies = ['core'];

export default func; 