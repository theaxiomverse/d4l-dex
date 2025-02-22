import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("\nDeploying Security components...");

    try {
        // Get core contract addresses
        const registry = await get('ContractRegistry');
        const tokenFactory = await get('TokenFactory');

        // Deploy AntiBot
        console.log("\n1. Deploying AntiBot...");
        const antiBot = await deploy('AntiBot', {
            from: deployer,
            contract: 'contracts/security/AntiBot.sol:AntiBot',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("AntiBot deployed to:", antiBot.address);

        // Deploy AntiRugPull
        console.log("\n2. Deploying AntiRugPull...");
        const antiRugPull = await deploy('AntiRugPull', {
            from: deployer,
            contract: 'contracts/security/AntiRugPull.sol:AntiRugPull',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("AntiRugPull deployed to:", antiRugPull.address);

        // Deploy SecurityOracle
        console.log("\n3. Deploying SecurityOracle...");
        const securityOracle = await deploy('SecurityOracle', {
            from: deployer,
            contract: 'contracts/security/SecurityOracle.sol:SecurityOracle',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("SecurityOracle deployed to:", securityOracle.address);

        // Register contracts in registry
        console.log("\nRegistering Security contracts in registry...");
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ANTI_BOT"),
            antiBot.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ANTI_RUG_PULL"),
            antiRugPull.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("SECURITY_ORACLE"),
            securityOracle.address
        );

        // Initialize Security components
        console.log("\nInitializing Security components...");
        
        // Set oracle in AntiBot
        await execute(
            'AntiBot',
            { from: deployer, log: true },
            'setSecurityOracle',
            securityOracle.address
        );

        // Set oracle in AntiRugPull
        await execute(
            'AntiRugPull',
            { from: deployer, log: true },
            'setSecurityOracle',
            securityOracle.address
        );

        // Set initial parameters for AntiBot
        await execute(
            'AntiBot',
            { from: deployer, log: true },
            'setParameters',
            {
                maxTransactionsPerBlock: 3,
                maxGasPrice: ethers.parseUnits("500", "gwei"),
                maxTransactionSize: 5000, // 50% of total supply
                cooldownPeriod: 60, // 1 minute
                blacklistThreshold: 3
            }
        );

        // Set initial parameters for AntiRugPull
        await execute(
            'AntiRugPull',
            { from: deployer, log: true },
            'setParameters',
            {
                maxSellPercentage: 1000, // 10%
                timeWindow: 3600, // 1 hour
                maxSellerCount: 100,
                liquidityLockPeriod: 180 * 24 * 3600, // 180 days
                minLiquidityRatio: 5000 // 50%
            }
        );

        // Enable protection for TokenFactory
        await execute(
            'AntiRugPull',
            { from: deployer, log: true },
            'enableProtection',
            tokenFactory.address
        );

        // Enable trading
        await execute(
            'AntiBot',
            { from: deployer, log: true },
            'enableTrading'
        );

        console.log("\nSecurity deployment completed successfully!");

    } catch (error) {
        console.error("Security deployment failed:", error);
        throw error;
    }
};

func.tags = ['security'];
func.dependencies = ['core'];

export default func; 