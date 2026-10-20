import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import * as dotenv from "dotenv";

dotenv.config();

const accounts = process.env.WALLET_PRIVATE_KEY ? [process.env.WALLET_PRIVATE_KEY] : [];
const rpc = (envKey: string, fallback: string) => process.env[envKey] ?? fallback;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
      evmVersion: "paris",
    },
  },
  networks: {
    "bsc-testnet": {
      url: rpc("BSC_TESTNET_RPC_URL", "https://bsc-testnet-dataseed.bnbchain.org"),
      accounts,
      chainId: 97,
    },
    "base-sepolia": {
      url: rpc("BASE_SEPOLIA_RPC_URL", "https://sepolia.base.org"),
      accounts,
      chainId: 84532,
    },
    "megaeth-testnet": {
      url: rpc("MEGAETH_TESTNET_RPC_URL", "https://carrot.megaeth.com/rpc"),
      accounts,
      chainId: 6342,
    },
    "pharos-testnet": {
      url: rpc("PHAROS_TESTNET_RPC_URL", "https://testnet.dplabs-internal.com"),
      accounts,
      chainId: 688688,
      gas: 12000000,
    },
    "pharos-devnet": {
      url: rpc("PHAROS_DEVNET_RPC_URL", "https://devnet.dplabs-internal.com"),
      accounts,
      chainId: 50002,
      gas: 12000000,
    },
    "optimism-sepolia": {
      url: rpc("OPTIMISM_SEPOLIA_RPC_URL", "https://sepolia.optimism.io"),
      accounts,
      chainId: 11155420,
    },
    "monad-testnet": {
      url: rpc("MONAD_TESTNET_RPC_URL", "https://testnet-rpc.monad.xyz"),
      accounts,
      chainId: 10143,
    },
    "ethereum-sepolia": {
      url: rpc("ETHEREUM_SEPOLIA_RPC_URL", "https://sepolia.drpc.org"),
      accounts,
      chainId: 11155111,
    },
    "scroll-sepolia": {
      url: rpc("SCROLL_SEPOLIA_RPC_URL", "https://sepolia-rpc.scroll.io"),
      accounts,
      chainId: 534351,
    },
    "mantle-sepolia": {
      url: rpc("MANTLE_SEPOLIA_RPC_URL", "https://rpc.sepolia.mantle.xyz"),
      accounts,
      chainId: 5003,
    },
  },
  // Verification is explorer-specific: every chain above needs its own API key
  // and, for non-Etherscan chains, a customChains entry. It stays disabled by
  // default so a missing key never blocks a deployment.
  // See scripts/README-deployment.md for how to enable it.
  etherscan: {
    enabled: false,
  },
};

export default config;
