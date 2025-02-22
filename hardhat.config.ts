import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-foundry";

import * as dotenv from "dotenv";

dotenv.config();

// Load environment variables
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0000000000000000000000000000000000000000000000000000000000000000";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.28",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            },
            viaIR: true
        }
    },
    namedAccounts: {
        deployer: {
            default: 0,
            1: 0,
            11155111: 0,
            84532: 0,
            8453: 0,
        },
        treasury: {
            default: 1,
            1: process.env.TREASURY_ADDRESS || "",
            11155111: process.env.TREASURY_ADDRESS || "",
            84532: process.env.TREASURY_ADDRESS || "",
            8453: process.env.TREASURY_ADDRESS || "",
        },
        feeCollector: {
            default: 2,
            1: process.env.FEE_COLLECTOR_ADDRESS || "",
            11155111: process.env.FEE_COLLECTOR_ADDRESS || "",
            84532: process.env.FEE_COLLECTOR_ADDRESS || "",
            8453: process.env.FEE_COLLECTOR_ADDRESS || "",
        }
    },
    networks: {
        hardhat: {
            chainId: 31337,
            allowUnlimitedContractSize: true,
            gas: "auto",
            gasPrice: "auto",
            mining: {
                auto: true,
                interval: 0
            },
            accounts: {
                mnemonic: "test test test test test test test test test test test junk",
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 10,
            },
        },
        localhost: {
            chainId: 31337,
            url: "http://127.0.0.1:8545/",
            allowUnlimitedContractSize: true,
            accounts: {
                mnemonic: "test test test test test test test test test test test junk",
                path: "m/44'/60'/0'/0",
                initialIndex: 0,
                count: 10,
            },
        },
        sepolia: {
            chainId: 11155111,
            url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [PRIVATE_KEY],
            verify: {
                etherscan: {
                    apiKey: ETHERSCAN_API_KEY
                }
            }
        },
        "base-sepolia": {
            chainId: 84532,
            url: "https://sepolia.base.org",
            accounts: [PRIVATE_KEY],
            verify: {
                etherscan: {
                    apiUrl: "https://api-sepolia.basescan.org"
                }
            }
        },
        mainnet: {
            chainId: 1,
            url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [PRIVATE_KEY],
            verify: {
                etherscan: {
                    apiKey: ETHERSCAN_API_KEY
                }
            }
        },
        base: {
            chainId: 8453,
            url: "https://mainnet.base.org",
            accounts: [PRIVATE_KEY],
            verify: {
                etherscan: {
                    apiUrl: "https://api.basescan.org"
                }
            }
        }
    },
    etherscan: {
        apiKey: {
            mainnet: ETHERSCAN_API_KEY,
            sepolia: ETHERSCAN_API_KEY,
            base: ETHERSCAN_API_KEY,
            "base-sepolia": ETHERSCAN_API_KEY
        },
        customChains: [
            {
                network: "base",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org"
                }
            },
            {
                network: "base-sepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org"
                }
            }
        ]
    },
    gasReporter: {
        enabled: true,
        currency: "USD",
        coinmarketcap: COINMARKETCAP_API_KEY,
        token: "ETH",
        gasPriceApi: "https://api.etherscan.io/api?module=proxy&action=eth_gasPrice",
        showTimeSpent: true,
        showMethodSig: true,
        maxMethodDiff: 10
    },
    typechain: {
        outDir: "../typechain-types",
        target: "ethers-v6"
    },
    paths: {
        root: ".",
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
        deploy: "./deploy",
        deployments: "./deployments"
    },
    mocha: {
        timeout: 40000
    }
};

export default config; 