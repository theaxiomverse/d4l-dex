import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers, upgrades } from 'hardhat';
import { Contract } from 'ethers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy, execute } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("Starting deployment...");
    console.log("Deploying with account:", deployer);

    try {
        // 1. Deploy WETH
        const weth = await deploy('WETH9', {
            from: deployer,
            contract: 'contracts/tokens/WETH9.sol:WETH9',
            args: [],
            log: true,
        });
        console.log("WETH deployed to:", weth.address);

        // 2. Deploy Registry
        const registry = await deploy('ContractRegistry', {
            from: deployer,
            contract: 'contracts/registry/ContractRegistry.sol:ContractRegistry',
            args: [],
            log: true,
        });
        console.log("ContractRegistry deployed to:", registry.address);

        // Register WETH first
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("WETH"),
            weth.address
        );

        // 3. Deploy HydraCurve
        console.log("\n3. Deploying HydraCurve...");
        const hydraCurve = await deploy('HydraCurve', {
            from: deployer,
            contract: 'contracts/curve/HydraCurve.sol:HydraCurve',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [deployer],
                },
            },
            log: true,
        });
        console.log("HydraCurve deployed to:", hydraCurve.address);

        // Register HydraCurve
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("HYDRA_CURVE"),
            hydraCurve.address
        );

        // Deploy TokenomicsRules
        console.log("\n3.5. Deploying TokenomicsRules...");
        const tokenomicsRules = await deploy('TokenomicsRules', {
            from: deployer,
            contract: 'contracts/tokenomics/tokenomics.sol:TokenomicsRules',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [deployer],
                },
            },
            log: true,
        });
        console.log("TokenomicsRules deployed to:", tokenomicsRules.address);

        // Register TokenomicsRules
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("TOKENOMICS"),
            tokenomicsRules.address
        );

        // 4. Deploy TokenFactory
        const tokenFactory = await deploy('TokenFactory', {
            from: deployer,
            contract: 'contracts/factory/TokenFactory.sol:TokenFactory',
            args: [
                weth.address,                // WETH
                tokenomicsRules.address,      // tokenomics
                deployer,                    // communityWallet
                deployer,                    // teamWallet
                deployer,                    // dexLiquidityWallet
                deployer,                    // treasuryWallet
                deployer,                    // marketingWallet
                deployer                     // cexLiquidityWallet
            ],
            log: true,
        });
        console.log("TokenFactory deployed to:", tokenFactory.address);

        // Register TokenFactory
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("TOKEN_FACTORY"),
            tokenFactory.address
        );

        // 5. Deploy UserToken implementation
        const userTokenImpl = await deploy('UserToken', {
            from: deployer,
            contract: 'contracts/tokens/UserToken.sol:UserToken',
            args: [],
            log: true,
        });
        console.log("UserToken implementation deployed to:", userTokenImpl.address);

        // Register UserToken implementation
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("USER_TOKEN_IMPL"),
            userTokenImpl.address
        );

        // Initialize TokenFactory with implementation
        await execute(
            'TokenFactory',
            { from: deployer, log: true },
            'setTokenImplementation',
            userTokenImpl.address
        );

        // 6. Deploy Controller first
        console.log("\n6. Deploying Controller...");
        const controller = await deploy('Degen4LifeController', {
            from: deployer,
            contract: 'contracts/Degen4LifeController.sol:Degen4LifeController',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("Controller deployed to:", controller.address);

        // Register Controller as POOL_CONTROLLER
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("POOL_CONTROLLER"),
            controller.address
        );

        // Register Controller as CONTROLLER
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("CONTROLLER"),
            controller.address
        );

        // 7. Deploy LiquidityModule
        console.log("\n7. Deploying LiquidityModule...");
        const liquidityModule = await deploy('LiquidityModule', {
            from: deployer,
            contract: 'contracts/modules/LiquidityModule.sol:LiquidityModule',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [weth.address, registry.address],
                },
            },
            log: true,
        });
        console.log("LiquidityModule deployed to:", liquidityModule.address);

        // Register LiquidityModule
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("LIQUIDITY_MODULE"),
            liquidityModule.address
        );

        // 8. Deploy SocialModule
        console.log("\n8. Deploying D4LSocialModule...");
        const socialModule = await deploy('D4LSocialModule', {
            from: deployer,
            contract: 'contracts/modules/D4LSocialModule.sol:D4LSocialModule',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("D4LSocialModule deployed to:", socialModule.address);

        // Register SocialModule
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("SOCIAL_MODULE"),
            socialModule.address
        );

        // 9. Deploy SocialTradingModule
        console.log("\n9. Deploying SocialTradingModule...");
        const socialTradingModule = await deploy('SocialTradingModule', {
            from: deployer,
            contract: 'contracts/modules/SocialTradingModule.sol:SocialTradingModule',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [registry.address],
                },
            },
            log: true,
        });
        console.log("SocialTradingModule deployed to:", socialTradingModule.address);

        // Register SocialTradingModule
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("SOCIAL_TRADING_MODULE"),
            socialTradingModule.address
        );

        // 9. Deploy Achievement and Badge NFTs first
        console.log("\n9.1 Deploying AchievementNFT...");
        const achievementNFT = await deploy('AchievementNFT', {
            from: deployer,
            contract: 'contracts/social/AchievementNFT.sol:AchievementNFT',
            args: ["Degen4Life Achievement", "D4LA", deployer],
            log: true,
        });
        console.log("AchievementNFT deployed to:", achievementNFT.address);

        console.log("\n9.2 Deploying BadgeNFT...");
        const badgeNFT = await deploy('BadgeNFT', {
            from: deployer,
            contract: 'contracts/social/BadgeNFT.sol:BadgeNFT',
            args: ["https://api.degen4life.com/badges/metadata/", deployer],
            log: true,
        });
        console.log("BadgeNFT deployed to:", badgeNFT.address);

        // 9.3 Deploy NFTFeatures
        console.log("\n9.3 Deploying NFTFeatures...");
        const nftFeatures = await deploy('NFTFeatures', {
            from: deployer,
            contract: 'contracts/social/NFTFeatures.sol:NFTFeatures',
            proxy: {
                proxyContract: 'OpenZeppelinTransparentProxy',
                execute: {
                    methodName: 'initialize',
                    args: [achievementNFT.address, badgeNFT.address],
                },
            },
            log: true,
        });
        console.log("NFTFeatures deployed to:", nftFeatures.address);

        // Register NFTFeatures
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("NFT_FEATURES"),
            nftFeatures.address
        );

        // Deploy AntiBot
        console.log("\n10. Deploying AntiBot...");
        const antiBot = await deploy('AntiBot', {
            from: deployer,
            contract: 'contracts/security/AntiBot.sol:AntiBot',
            args: [],
            log: true,
        });
        console.log("AntiBot deployed to:", antiBot.address);

        // Register AntiBot
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ANTI_BOT"),
            antiBot.address
        );

        // Enable trading on AntiBot
        await execute(
            'AntiBot',
            { from: deployer, log: true },
            'enableTrading'
        );

        // Deploy AntiRugPull
        console.log("\n11. Deploying AntiRugPull...");
        const antiRugPull = await deploy('AntiRugPull', {
            from: deployer,
            contract: 'contracts/security/AntiRugPull.sol:AntiRugPull',
            args: [],
            log: true,
        });
        console.log("AntiRugPull deployed to:", antiRugPull.address);

        // Register AntiRugPull
        await execute(
            'ContractRegistry',
            { from: deployer, log: true },
            'setContractAddress',
            ethers.id("ANTI_RUG_PULL"),
            antiRugPull.address
        );

        // Enable protection on AntiRugPull
        await execute(
            'AntiRugPull',
            { from: deployer, log: true },
            'enableProtection',
            tokenFactory.address
        );

        // Set pool controller in TokenFactory
        await execute(
            'TokenFactory',
            { from: deployer, log: true },
            'setPoolController',
            controller.address
        );

        // Set system addresses in Controller
        await execute(
            'Degen4LifeController',
            { from: deployer, log: true },
            'setSystemAddresses',
            {
                tokenFactory: tokenFactory.address,
                poolController: controller.address,
                feeHandler: deployer,
                userProfile: nftFeatures.address,
                antiBot: antiBot.address,
                antiRugPull: antiRugPull.address,
                governance: deployer,
                hydraCurve: hydraCurve.address,
                socialOracle: deployer,
                dao: deployer,
                dex: deployer,
                ens: deployer,
                predictionMarket: deployer
            }
        );

        // Initialize modules in Controller
        await execute(
            'Degen4LifeController',
            { from: deployer, log: true },
            'initializeModules',
            antiBot.address,
            liquidityModule.address,
            socialModule.address,
            socialTradingModule.address,
            deployer, // dex
            deployer, // ens
            deployer  // predictionMarket
        );

        console.log("\nDeployment completed successfully!");

    } catch (error) {
        console.error("Deployment failed:", error);
        throw error;
    }
};

func.tags = ['core'];
func.dependencies = [];

export default func; 