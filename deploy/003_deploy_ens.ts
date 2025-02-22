import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute, get } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("\nDeploying ENS components...");

    try {
        // Get core contract addresses
        const registry = await get('ContractRegistry');

        // Deploy DegenENS
        console.log("\n1. Deploying DegenENS...");
        const ens = await deploy('DegenENS', {
            from: deployer,
            contract: 'contracts/ens/DegenENS.sol:DegenENS',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("DegenENS deployed to:", ens.address);

        // Deploy ENSResolver
        console.log("\n2. Deploying ENSResolver...");
        const resolver = await deploy('ENSResolver', {
            from: deployer,
            contract: 'contracts/ens/ENSResolver.sol:ENSResolver',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [ens.address],
                },
            },
            log: true,
        });
        console.log("ENSResolver deployed to:", resolver.address);

        // Deploy ENSRegistrar
        console.log("\n3. Deploying ENSRegistrar...");
        const registrar = await deploy('ENSRegistrar', {
            from: deployer,
            contract: 'contracts/ens/ENSRegistrar.sol:ENSRegistrar',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [ens.address, resolver.address],
                },
            },
            log: true,
        });
        console.log("ENSRegistrar deployed to:", registrar.address);

        // Register contracts in registry
        console.log("\nRegistering ENS contracts in registry...");
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ENS"),
            ens.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ENS_RESOLVER"),
            resolver.address
        );

        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ENS_REGISTRAR"),
            registrar.address
        );

        // Initialize ENS components
        console.log("\nInitializing ENS components...");
        
        // Set registrar in ENS
        await execute(
            'DegenENS',
            { from: deployer, log: true },
            'setRegistrar',
            registrar.address
        );

        // Set resolver in ENS
        await execute(
            'DegenENS',
            { from: deployer, log: true },
            'setDefaultResolver',
            resolver.address
        );

        // Set initial parameters
        await execute(
            'ENSRegistrar',
            { from: deployer, log: true },
            'setParameters',
            {
                minRegistrationDuration: 30 * 24 * 3600, // 30 days
                maxRegistrationDuration: 365 * 24 * 3600, // 1 year
                minNameLength: 3,
                baseRentPrice: ethers.parseEther("0.01"), // 0.01 ETH per year
                premium3Letter: ethers.parseEther("1"), // 1 ETH premium for 3 letter names
                premium4Letter: ethers.parseEther("0.1"), // 0.1 ETH premium for 4 letter names
                gracePeriod: 90 * 24 * 3600 // 90 days grace period
            }
        );

        // Set root node
        await execute(
            'DegenENS',
            { from: deployer, log: true },
            'setRootNode',
            ethers.id("d4l")
        );

        console.log("\nENS deployment completed successfully!");

    } catch (error) {
        console.error("ENS deployment failed:", error);
        throw error;
    }
};

func.tags = ['ens'];
func.dependencies = ['core'];

export default func; 