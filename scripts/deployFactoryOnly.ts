import { ethers } from "hardhat";

async function main() {
  console.log("Deploy Factory contract...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer account:", deployer.address);
  console.log(
    "Account balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH\n",
  );

  // Replace with your deployed contract addresses
  const REGISTRY_ADDRESS = "0x..."; // Replace with your Registry contract address
  const FEE_VAULT_ADDRESS = "0x..."; // Replace with your FeeVault contract address
  const PRICE_CONTRACT_ADDRESS = "0x..."; // Replace with your Price contract address
  const Flip_IMPLEMENTATION_ADDRESS = "0x..."; // Replace with your Flip Implementation contract address

  // Verify if the addresses are set
  const addresses = [
    { name: "Registry", address: REGISTRY_ADDRESS },
    { name: "FeeVault", address: FEE_VAULT_ADDRESS },
    { name: "Price Contract", address: PRICE_CONTRACT_ADDRESS },
    { name: "Flip Implementation", address: Flip_IMPLEMENTATION_ADDRESS },
  ];

  for (const { name, address } of addresses) {
    if (address === "0x...") {
      throw new Error(`Please set the ${name} contract address`);
    }
    if (!ethers.isAddress(address)) {
      throw new Error(`${name} address format is invalid: ${address}`);
    }
  }

  console.log("Used dependent contract addresses:");
  addresses.forEach(({ name, address }) => {
    console.log(`  ${name}: ${address}`);
  });
  console.log();

  // Deploy Factory contract
  console.log("1. Deploy Factory contract...");
  const Factory = await ethers.getContractFactory("Factory");
  const factory = await Factory.deploy(
    REGISTRY_ADDRESS,
    FEE_VAULT_ADDRESS,
    PRICE_CONTRACT_ADDRESS,
    Flip_IMPLEMENTATION_ADDRESS,
  );
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("   Factory deployed address:", factoryAddress);

  // Verify contract status
  console.log("\n=== Verify Factory contract configuration ===");
  console.log("  Registry address:", await factory.registry());
  console.log("  FeeVault address:", await factory.feeVault());
  console.log("  Price contract address:", await factory.priceContract());
  console.log("  Flip Implementation address:", await factory.Flip_IMPLEMENTATION());

  // Deployment summary
  console.log("\n=== Deployment summary ===");
  console.log("Deployer account:", deployer.address);
  console.log("Network:", (await ethers.provider.getNetwork()).name || "unknown");
  console.log("Chain ID:", (await ethers.provider.getNetwork()).chainId);
  console.log("Factory address:", factoryAddress);

  // Verification commands
  console.log("\n=== Verification commands ===");
  console.log("Verify Factory:");
  console.log(
    `npx hardhat verify --network <network-name> ${factoryAddress} "${REGISTRY_ADDRESS}" "${FEE_VAULT_ADDRESS}" "${PRICE_CONTRACT_ADDRESS}" "${Flip_IMPLEMENTATION_ADDRESS}"`,
  );

  return {
    factory: factoryAddress,
  };
}

main()
  .then((deployedContracts) => {
    console.log("\n✅ Factory contract deployed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  });
