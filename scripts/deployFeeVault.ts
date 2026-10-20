import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);
  console.log(
    "Balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH",
  );

  const feeVault = await ethers.deployContract("FeeVault");
  await feeVault.waitForDeployment();

  const address = await feeVault.getAddress();
  console.log("FeeVault deployed to:", address);
  console.log("Admin:", await feeVault.admin());
  console.log("Protocol fee percent:", ethers.formatEther(await feeVault.protocolFeePercent()));
  console.log(`Verify with: npx hardhat verify --network <network> ${address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
