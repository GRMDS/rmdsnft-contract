### Instructions to build and deploy the contracts

The latest version of the contracts are deployed on Cube Testnet at these addresses:

### Cube Chain Testnet contracts deployment:
NFT deployed at: 0xC54422cb678d47782E9D785d080B08520EB88A86
AuctionHouse deployed at: 0xC8BEe4404ac2Ef933654a8BD8cFA97Db5C08E1E0

### Whitelist Cube Chain Testnet contracts deployment:
NFT deployed at: 0x086b1373c493e2B936e6e89Ea43f5e045437FD5b
AuctionHouse deployed at: 0xcC4A957ac43775F338953386CE38BA3368E23efd

To re-compile, add a .env file with the following env variables in the contracts/evm/contracts/.env file. See .env.sample for reference.

``PRIVATE_KEY``, ``FEE_PERCENT`` 

- Private key is the private key of the owner's account (multisig account)
- Fee percent is set to 250 which comes to (2.5%)



