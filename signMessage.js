import Web3 from "web3";
import dotenv from "dotenv";

dotenv.config();
const web3 = new Web3(process.env.MAINNET_RPC_URL);

const generateNonce = () => {
  return crypto.randomBytes(16).toString("hex");
};

const mintMsgHash = (recipient, uri, newNonce, contract) => {
  return (
    web3.utils.soliditySha3(
      { t: "address", v: recipient },
      { t: "string", v: uri },
      { t: "string", v: newNonce },
      { t: "address", v: contract }
    ) || ""
  );
};

const signMessage = (msgHash, privateKey) => {
    return web3.eth.accounts.sign(msgHash, privateKey);
};

// Signing the message at backend.
// You can store the data at database or check for Nonce conflict 
export const Signing = (address, uri) => {
  const newNonce = generateNonce();
 
  const hash = mintMsgHash(
    address,
    uri,
    newNonce,
    config.ContractAddress
  );

  const signner = signMessage(hash, config.PrivateKey);
  
  return {
    uri: uri,
    nonce: newNonce,
    hash: signner.message,
    signature: signner.signature,
  }; 
}