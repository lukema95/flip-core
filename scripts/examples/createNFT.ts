import { ethers } from "hardhat";
import type { Log } from "ethers";

type ParsedLog = { name: string; args: any[] };

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value || !ethers.isAddress(value)) {
    throw new Error(`Set ${name} to a valid contract address (see .env.example)`);
  }
  return value;
}

async function main() {
  const factoryAddress = requiredEnv("FACTORY_ADDRESS");

  const params = {
    name: "FlipTest",
    symbol: "FlipTEST",
    initialPrice: ethers.parseEther("0.001"),
    maxSupply: 10000n,
    maxPrice: 0n,
    creatorFeePercent: ethers.parseEther("0.05"), // 5%
    baseUri: "https://example.com/metadata",
  };

  const factory = await ethers.getContractAt("Factory", factoryAddress);

  console.log("Creating a collection...");
  const tx = await factory.createFlip(
    params.name,
    params.symbol,
    params.initialPrice,
    params.maxSupply,
    params.maxPrice,
    params.creatorFeePercent,
    params.baseUri,
  );

  console.log("Transaction hash:", tx.hash);
  const receipt = await tx.wait();

  const event = receipt?.logs
    .map((log: Log) => {
      try {
        return factory.interface.parseLog({ topics: log.topics as string[], data: log.data });
      } catch {
        return null;
      }
    })
    .find((parsed: ParsedLog | null) => parsed?.name === "FlipCreated");

  if (event) {
    console.log("Collection created at:", event.args[1]);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
