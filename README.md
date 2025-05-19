# MerkleNFT

A simple ERC721 NFT smart contract with Merkle tree whitelist verification, public minting, and royalty support.

## Features

- **Merkle Tree Whitelist**: Gas-efficient whitelist verification using Merkle proofs
- **Dual Sale Phases**: Separate whitelist and public sale phases
- **Fixed Supply**: Maximum token count is set at deployment and cannot be changed
- **Hidden Metadata**: Pre-reveal placeholder metadata for all tokens
- **Metadata Reveal**: Owner can reveal the collection when ready
- **ERC721Enumerable**: Full enumeration support for all tokens
- **Royalties Support**: Implements ERC-2981 for marketplace royalties

## Prerequisites

- [Node.js](https://nodejs.org/) (>= 14.x)
- [npm](https://www.npmjs.com/) (>= 6.x)
- [Hardhat](https://hardhat.org/) or [Truffle](https://trufflesuite.com/)
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts)

## Installation

1. Create a new project directory and initialize it:

```bash
mkdir my-nft-project
cd my-nft-project
npm init -y
```

2. Install required dependencies:

```bash
npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers @nomiclabs/hardhat-waffle @openzeppelin/contracts dotenv keccak256 merkletreejs
```

3. Initialize Hardhat:

```bash
npx hardhat
```

4. Create a `contracts` directory and add the MerkleNFT contract:

```bash
mkdir contracts
```

5. Create a file named `MerkleNFT.sol` in the contracts directory and copy the contract code into it.

## Deployment

1. Create a deployment script in the `scripts` directory:

```javascript
// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy MerkleNFT contract
  const MerkleNFT = await hre.ethers.getContractFactory("MerkleNFT");
  const merkleNFT = await MerkleNFT.deploy(
    "MyNFTCollection",                // Collection name
    "MNFT",                           // Symbol
    10000,                            // Maximum supply
    "ipfs://QmYourHiddenURI/hidden.json", // Hidden metadata URI
    deployer.address,                 // Royalty receiver address
    500                               // Royalty percentage (5%)
  );

  await merkleNFT.deployed();
  console.log("MerkleNFT deployed to:", merkleNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

2. Configure Hardhat network settings in `hardhat.config.js`

3. Deploy the contract:

```bash
npx hardhat run scripts/deploy.js --network <your-network>
```

## Merkle Tree Whitelist Setup

The Merkle tree-based whitelist approach is a gas-efficient way to verify addresses without storing all of them on-chain. Here's how to set it up:

### 1. Generate Merkle Tree

Create a script to generate your Merkle tree and root hash:

```javascript
// scripts/generate-merkle-root.js
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');

// List of whitelisted addresses
const whitelistAddresses = [
  "0xabc...",
  "0xdef...",
  "0x123...",
  // Add more addresses here
];

// Create leaf nodes by hashing addresses
const leafNodes = whitelistAddresses.map(addr => keccak256(addr));

// Create Merkle Tree
const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });

// Get root hash
const rootHash = merkleTree.getRoot().toString('hex');
console.log('Merkle Root:', '0x' + rootHash);

// Save merkle tree for future proof generation
fs.writeFileSync('merkleTree.json', JSON.stringify({
  addresses: whitelistAddresses,
  root: '0x' + rootHash,
  tree: merkleTree.toString()
}));
```

Run this script to generate your Merkle root:

```bash
node scripts/generate-merkle-root.js
```

### 2. Set Merkle Root in Contract

Use the root hash to set the Merkle root in your contract:

```javascript
// scripts/set-merkle-root.js
const hre = require("hardhat");
const fs = require('fs');

async function main() {
  const merkleData = JSON.parse(fs.readFileSync('merkleTree.json'));
  const rootHash = merkleData.root;
  
  const contract = await hre.ethers.getContractAt(
    "MerkleNFT", 
    "YOUR_DEPLOYED_CONTRACT_ADDRESS"
  );
  
  const tx = await contract.setMerkleRoot(rootHash);
  await tx.wait();
  
  console.log("Merkle root set:", rootHash);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
```

### 3. Generate Merkle Proofs for Users

Create a script or API endpoint that generates Merkle proofs for users trying to mint:

```javascript
// scripts/generate-proof.js
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const fs = require('fs');

function getProof(address) {
  const merkleData = JSON.parse(fs.readFileSync('merkleTree.json'));
  const addresses = merkleData.addresses;
  
  // Recreate the merkle tree
  const leafNodes = addresses.map(addr => keccak256(addr));
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true });
  
  // Check if address is in whitelist
  if (!addresses.includes(address)) {
    console.log('Address not in whitelist');
    return null;
  }
  
  // Get proof for the address
  const leaf = keccak256(address);
  const proof = merkleTree.getHexProof(leaf);
  
  console.log('Merkle Proof for', address, ':', proof);
  return proof;
}

// Example usage
getProof("0xabc...");
```

## Usage Guide

### Setting Up Sale States

After deployment, set up your sale state:

```javascript
// Start whitelist sale
await merkleNFT.setSaleState(1); // 1 = Whitelist sale

// Later, switch to public sale
await merkleNFT.setSaleState(2); // 2 = Public sale

// Pause sales
await merkleNFT.setSaleState(0); // 0 = Inactive
```

### Setting Mint Prices

```javascript
// Set prices (in wei)
const whitelistPrice = ethers.utils.parseEther("0.05");
const publicPrice = ethers.utils.parseEther("0.08");
await merkleNFT.setMintPrices(whitelistPrice, publicPrice);
```

### Setting Max Limits

```javascript
// Set max mints per wallet and per transaction
await merkleNFT.setMaxLimits(5, 3); // 5 per wallet, 3 per transaction
```

### Setting Up Metadata

#### Hidden Metadata

Before revealing your collection, all tokens will return the same hidden metadata URI. This should point to a JSON file with placeholder information:

```json
{
  "name": "Hidden NFT",
  "description": "This NFT has not been revealed yet!",
  "image": "ipfs://QmYourHiddenImageCID/hidden.png"
}
```

#### Revealed Metadata

Prepare your revealed metadata with sequential JSON files. For example, if your base URI is `ipfs://QmRevealedCID/`, then token ID 1 would fetch `ipfs://QmRevealedCID/1.json`.

Each JSON file should follow a structure like:

```json
{
  "name": "NFT #1",
  "description": "Description for NFT #1",
  "image": "ipfs://QmYourImagesCID/1.png",
  "attributes": [
    {
      "trait_type": "Background",
      "value": "Blue"
    },
    {
      "trait_type": "Eyes",
      "value": "Green"
    }
  ]
}
```

### Minting NFTs

#### Whitelist Minting

Users on the whitelist can mint by providing a Merkle proof:

```javascript
// Frontend whitelist minting example
import { ethers } from 'ethers';

// This function would be part of your frontend
async function whitelistMint(quantity, proof) {
  const contractAddress = "0xYourContractAddress";
  const abi = [...]; // The ABI of your contract
  
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();
  const contract = new ethers.Contract(contractAddress, abi, signer);
  
  // Calculate price
  const price = ethers.utils.parseEther("0.05").mul(quantity);
  
  // Call the mint function with proof
  const tx = await contract.whitelistMint(quantity, proof, { value: price });
  await tx.wait();
  
  console.log("Minted successfully!");
}

// To use this function, you would need to fetch the proof for the user from your backend
// Example: 
// const proof = await fetchProofFromBackend(userAddress);
// whitelistMint(2, proof);
```

#### Public Minting

Anyone can mint during the public sale:

```javascript
// Frontend public minting example
async function publicMint(quantity) {
  const contractAddress = "0xYourContractAddress";
  const abi = [...]; // The ABI of your contract
  
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();
  const contract = new ethers.Contract(contractAddress, abi, signer);
  
  // Calculate price
  const price = ethers.utils.parseEther("0.08").mul(quantity);
  
  // Call the mint function
  const tx = await contract.publicMint(quantity, { value: price });
  await tx.wait();
  
  console.log("Minted successfully!");
}
```

### Owner Functions

#### Revealing the Collection

When you're ready to reveal your collection:

```javascript
const revealedBaseURI = "ipfs://QmYourRevealedMetadataCID/";
const tx = await contract.revealCollection(revealedBaseURI);
await tx.wait();
```

#### Updating Royalty Information

```javascript
const newReceiver = "0xNewRoyaltyReceiverAddress";
const newPercentage = 1000; // 10%
const tx = await contract.setRoyaltyInfo(newReceiver, newPercentage);
await tx.wait();
```

#### Withdrawing Funds

```javascript
const tx = await contract.withdraw();
await tx.wait();
```

## Contract Functions Reference

### Whitelist Management

- **setMerkleRoot(bytes32 _merkleRoot)**: Sets the Merkle root for whitelist verification.
  - Can only be called by the owner
  - This is the hash that will be used to verify whitelist membership

### Sale Management

- **setSaleState(SaleState _saleState)**: Sets the current sale state.
  - Can only be called by the owner
  - State: 0 = Inactive, 1 = Whitelist, 2 = Public

- **setMintPrices(uint256 _whitelistPrice, uint256 _publicPrice)**: Sets the mint prices.
  - Can only be called by the owner
  - Prices are in wei

- **setMaxLimits(uint256 _maxPerWallet, uint256 _maxPerTransaction)**: Sets the maximum mint limits.
  - Can only be called by the owner
  - Applies to both whitelist and public sales

### Minting Functions

- **whitelistMint(uint256 quantity, bytes32[] calldata proof)**: Mints NFTs for whitelisted addresses.
  - Only available during whitelist sale
  - Requires a valid Merkle proof
  - Each address can only claim once during whitelist
  - Requires correct payment amount

- **publicMint(uint256 quantity)**: Mints NFTs during public sale.
  - Only available during public sale
  - Enforces per-wallet limit
  - Requires correct payment amount

### Metadata and Royalties

- **tokenURI(uint256 tokenId)**: Returns the metadata URI for a specific token.
  - Returns hiddenBaseURI if the collection is not revealed
  - Returns the token-specific URI if the collection is revealed

- **revealCollection(string memory _revealedBaseURI)**: Reveals the collection with the specified base URI.
  - Can only be called by the owner
  - Sets isRevealed to true

- **royaltyInfo(uint256 tokenId, uint256 salePrice)**: Returns royalty information for a token.
  - Implements ERC-2981 standard
  - Returns the royalty receiver address and the royalty amount based on the sale price

- **setRoyaltyInfo(address _receiver, uint96 _percentage)**: Updates royalty information.
  - Can only be called by the owner
  - Percentage is in basis points (e.g., 500 = 5%)
  - Maximum percentage is 10000 (100%)

### Administration

- **withdraw()**: Withdraws all funds from the contract to the owner's address.
  - Can only be called by the owner

## Sale State Explained

The contract uses an enum `SaleState` to track the current state of the sale:

1. **Inactive**: Minting is disabled
2. **Whitelist**: Only addresses on the whitelist (verified by Merkle proof) can mint
3. **Public**: Anyone can mint, subject to per-wallet limits

## Merkle Tree Whitelist Explained

A Merkle tree is a binary tree structure where each leaf node is a hash of transaction data, and each non-leaf node is a hash of its two child hashes. This allows for efficient verification of large datasets.

Benefits of using a Merkle tree for whitelisting:
- Gas-efficient: The contract only needs to store a single root hash, not all whitelisted addresses
- Secure: Cryptographically verifiable
- Scalable: Can handle thousands of addresses with minimal on-chain storage

How verification works:
1. The contract stores only the Merkle root
2. When minting, the user provides a Merkle proof (a list of hashes)
3. The contract uses the proof and the user's address to determine if they're in the whitelist
4. If the verification passes, the user can mint their NFT

## Security Considerations

- The contract uses OpenZeppelin's battle-tested libraries for security
- Constructor parameters cannot be changed after deployment (particularly maxSupply)
- Owner functions are protected with the Ownable modifier
- Whitelist addresses can only mint once during the whitelist phase
- Public minting has per-wallet limits to prevent concentration
- Consider a professional audit before deploying with significant value

## License

This project is licensed under the MIT License - see the LICENSE file for details.
