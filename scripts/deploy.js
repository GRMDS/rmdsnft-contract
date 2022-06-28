require("@nomiclabs/hardhat-ethers");
require('dotenv').config();
const assert = require('assert').strict;

const main = async () => {
  const MarketPlace = await ethers.getContractFactory("AuctionHouse");
  const feePercent = parseInt(process.env.FEE_PERCENT);
  assert.ok(feePercent, 'The "FEE_PERCENT" environment variable is required');
  const marketPlace = await MarketPlace.deploy(feePercent);
  await marketPlace.deployed();
  const marketPlaceAddress = await marketPlace.address;

  const NFTToken = await ethers.getContractFactory("RMDSNFT");
  const nftToken = await NFTToken.deploy(marketPlaceAddress);
  await nftToken.deployed();
  const nftTokenAddress = await nftToken.address;

  console.log(`NFT deployed at: ${nftTokenAddress}`);
  console.log(`AuctionHouse deployed at: ${marketPlaceAddress}`);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
