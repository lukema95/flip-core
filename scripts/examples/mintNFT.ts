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
  const flipAddress = requiredEnv("FLIP_ADDRESS");
  const tradeAddress = requiredEnv("TRADE_ADDRESS");

  const flip = await ethers.getContractAt("Flip", flipAddress);
  const priceAddress = await flip.priceContract();
  const price = await ethers.getContractAt("Price", priceAddress);
  const trade = await ethers.getContractAt("Trade", tradeAddress);

  console.log(`Collection: ${flipAddress}`);
  console.log(`Buy price:  ${ethers.formatEther(await price.getBuyPrice(flipAddress))} ETH`);
  console.log(`Sell price: ${ethers.formatEther(await price.getSellPrice(flipAddress))} ETH`);

  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();
  const balance = await ethers.provider.getBalance(signerAddress);
  const mintPrice = await price.getBuyPriceAfterFee(flipAddress);

  console.log(`Minter: ${signerAddress}`);
  console.log(`Balance: ${ethers.formatEther(balance)} ETH`);
  console.log(`Mint price: ${ethers.formatEther(mintPrice)} ETH`);

  if (balance < mintPrice) {
    throw new Error("Insufficient balance to mint");
  }

  const tx = await trade.mint(flipAddress, { value: mintPrice });
  console.log("Transaction hash:", tx.hash);
  const receipt = await tx.wait();

  const event = receipt?.logs
    .map((log: Log) => {
      try {
        return flip.interface.parseLog({ topics: log.topics as string[], data: log.data });
      } catch {
        return null;
      }
    })
    .find((parsed: ParsedLog | null) => parsed?.name === "TokenMinted");

  if (event) {
    console.log("Minted tokenId:", event.args[1].toString());
    console.log("Paid:", ethers.formatEther(event.args[2]), "ETH");
    console.log("Creator fee:", ethers.formatEther(event.args[3]), "ETH");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
