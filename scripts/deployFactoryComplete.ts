import { ethers } from "hardhat";
import { Contract } from "ethers";

async function main() {
  console.log("Start deploying Flip system contracts...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer account:", deployer.address);
  console.log(
    "Account balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH\n",
  );

  // 1. Deploy FeeVault contract
  console.log("1. Deploy FeeVault contract...");
  const FeeVault = await ethers.getContractFactory("FeeVault");
  const feeVault = await FeeVault.deploy();
  await feeVault.waitForDeployment();
  const feeVaultAddress = await feeVault.getAddress();
  console.log("   FeeVault deployed address:", feeVaultAddress);

  // 2. Deploy Registry contract
  console.log("\n2. Deploy Registry contract...");
  const Registry = await ethers.getContractFactory("Registry");
  const registry = await Registry.deploy();
  await registry.waitForDeployment();
  const registryAddress = await registry.getAddress();
  console.log("   Registry deployed address:", registryAddress);

  // 3. Deploy Price contract
  console.log("\n3. Deploy Price contract...");
  const Price = await ethers.getContractFactory("Price");
  const priceContract = await Price.deploy();
  await priceContract.waitForDeployment();
  const priceContractAddress = await priceContract.getAddress();
  console.log("   Price deployed address:", priceContractAddress);

  // 4. Deploy Flip implementation contract
  console.log("\n4. Deploy Flip implementation contract...");
  const Flip = await ethers.getContractFactory("Flip");
  const flipImplementation = await Flip.deploy();
  await flipImplementation.waitForDeployment();
  const flipImplementationAddress = await flipImplementation.getAddress();
  console.log("   Flip Implementation deployed address:", flipImplementationAddress);

  // 5. Deploy Factory contract
  console.log("\n5. Deploy Factory contract...");
  const Factory = await ethers.getContractFactory("Factory");
  const factory = await Factory.deploy(
    registryAddress,
    feeVaultAddress,
    priceContractAddress,
    flipImplementationAddress,
  );
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("   Factory deployed address:", factoryAddress);

  // Verify contract status
  console.log("\n=== Deployment completed, verify contract status ===");

  console.log("\nFactory contract configuration:");
  console.log("  Registry address:", await factory.registry());
  console.log("  FeeVault address:", await factory.feeVault());
  console.log("  Price contract address:", await factory.priceContract());
  console.log("  Flip Implementation address:", await factory.Flip_IMPLEMENTATION());

  console.log("\nFeeVault contract configuration:");
  console.log("  Admin address:", await feeVault.admin());
  console.log(
    "  Protocol fee rate:",
    ethers.formatEther(await feeVault.protocolFeePercent()),
    "(",
    Number(ethers.formatEther(await feeVault.protocolFeePercent())) * 100,
    "%)",
  );

  // Deployment summary
  console.log("\n=== Deployment summary ===");
  console.log("Deployer account:", deployer.address);
  console.log("Network:", (await ethers.provider.getNetwork()).name || "unknown");
  console.log("Chain ID:", (await ethers.provider.getNetwork()).chainId);

  const deployedContracts = {
    FeeVault: feeVaultAddress,
    Registry: registryAddress,
    Price: priceContractAddress,
    FlipImplementation: flipImplementationAddress,
    Factory: factoryAddress,
  };

  console.log("\nDeployed contract addresses:");
  Object.entries(deployedContracts).forEach(([name, address]) => {
    console.log(`  ${name}: ${address}`);
  });

  return deployedContracts;
}

main()
  .then((deployedContracts) => {
    console.log("\n✅ All contracts deployed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  });
