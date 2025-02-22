import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("\nDeploying DEX components...");

    try {
        // Get core contract addresses
        const registry = await get('ContractRegistry');
        const weth = await get('WETH9');

        // Deploy PriceOracle
        console.log("\n1. Deploying PriceOracle...");
        const priceOracle = await deploy('PriceOracle', {
            from: deployer,
            contract: 'contracts/dex/PriceOracle.sol:PriceOracle',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [
                        registry.address,
                        [ // Default tokens
                            weth.address, // WETH/ETH feed
                            "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb", // USDT
                            "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"  // USDC
                        ],
                        [ // Chainlink price feeds on Base
                            "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70", // ETH/USD
                            "0x0a023a3423D9b27A0BE48c768CCF2dD7877fEf5E", // USDT/USD
                            "0x7e860098F58bBFC8648a4311b374B1D669a2bc6B"  // USDC/USD
                        ]
                    ],
                },
            },
            log: true,
        });
        console.log("PriceOracle deployed to:", priceOracle.address);

        // Deploy LiquidityPool
        console.log("\n2. Deploying LiquidityPool...");
        const liquidityPool = await deploy('LiquidityPool', {
            from: deployer,
            contract: 'contracts/dex/LiquidityPool.sol:LiquidityPool',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address, weth.address],
                },
            },
            log: true,
        });
        console.log("LiquidityPool deployed to:", liquidityPool.address);

        // Deploy LiquidityModule
        console.log("\n3. Deploying LiquidityModule...");
        const liquidityModule = await deploy('LiquidityModule', {
            from: deployer,
            contract: 'contracts/modules/LiquidityModule.sol:LiquidityModule',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address, weth.address],
                },
            },
            log: true,
        });
        console.log("LiquidityModule deployed to:", liquidityModule.address);

        // Deploy DEX
        console.log("\n4. Deploying Degen4LifeDEX...");
        const dex = await deploy('Degen4LifeDEX', {
            from: deployer,
            contract: 'contracts/dex/Degen4LifeDEX.sol:Degen4LifeDEX',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address, weth.address],
                },
            },
            log: true,
        });
        console.log("Degen4LifeDEX deployed to:", dex.address);

        // Register contracts in registry
        console.log("\nRegistering DEX contracts in registry...");
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("PRICE_ORACLE"),
            priceOracle.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("LIQUIDITY_POOL"),
            liquidityPool.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("LIQUIDITY_MODULE"),
            liquidityModule.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("DEX"),
            dex.address
        );

        // Initialize DEX components
        console.log("\nInitializing DEX components...");

        // Set DEX in LiquidityPool
        await execute(
            'LiquidityPool',
            { from: deployer, log: true },
            'setDEX',
            dex.address
        );

        // Set LiquidityPool in DEX
        await execute(
            'Degen4LifeDEX',
            { from: deployer, log: true },
            'setLiquidityPool',
            liquidityPool.address
        );

        // Set PriceOracle in DEX
        await execute(
            'Degen4LifeDEX',
            { from: deployer, log: true },
            'setPriceOracle',
            priceOracle.address
        );

        // Accept default tokens in DEX
        await execute(
            'Degen4LifeDEX',
            { from: deployer, log: true },
            'setAcceptedToken',
            "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb", // USDT
            true
        );

        await execute(
            'Degen4LifeDEX',
            { from: deployer, log: true },
            'setAcceptedToken',
            "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC
            true
        );

        console.log("\nDEX deployment completed successfully!");

    } catch (error) {
        console.error("DEX deployment failed:", error);
        throw error;
    }
};

func.tags = ['dex'];
func.dependencies = ['core'];

export default func; 