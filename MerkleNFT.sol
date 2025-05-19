// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleNFT is ERC721Enumerable, Ownable, IERC2981 {
    using Strings for uint256;
    
    // Maximum supply of tokens
    uint256 public immutable maxSupply;
    
    // Mint prices
    uint256 public whitelistPrice = 0.05 ether;
    uint256 public publicPrice = 0.08 ether;
    
    // Sale status
    enum SaleState { Inactive, Whitelist, Public }
    SaleState public saleState = SaleState.Inactive;
    
    // Hidden URI for metadata before reveal
    string private hiddenBaseURI;
    
    // Revealed URI for metadata after reveal
    string private revealedBaseURI;
    
    // Flag to check if collection is revealed
    bool public isRevealed = false;
    
    // Royalty information
    address private royaltyReceiver;
    uint96 private royaltyPercentage;
    
    // Merkle root for whitelist verification
    bytes32 public merkleRoot;
    
    // Whitelist claimed mapping
    mapping(address => bool) public whitelistClaimed;
    
    // Max mint per wallet/transaction
    uint256 public maxPerWallet = 5;
    uint256 public maxPerTransaction = 5;
    
    // Tracking wallet mints for public sale
    mapping(address => uint256) public publicMinted;
    
    // Events
    event MerkleRootSet(bytes32 merkleRoot);
    event SaleStateUpdated(SaleState saleState);
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _hiddenBaseURI,
        address _royaltyReceiver,
        uint96 _royaltyPercentage
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        hiddenBaseURI = _hiddenBaseURI;
        royaltyReceiver = _royaltyReceiver;
        royaltyPercentage = _royaltyPercentage;
    }
    
    // Helper function to check if token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= totalSupply();
    }
    
    // Set merkle root for whitelist verification
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootSet(_merkleRoot);
    }
    
    // Set sale state
    function setSaleState(SaleState _saleState) external onlyOwner {
        saleState = _saleState;
        emit SaleStateUpdated(_saleState);
    }
    
    // Set mint prices
    function setMintPrices(uint256 _whitelistPrice, uint256 _publicPrice) external onlyOwner {
        whitelistPrice = _whitelistPrice;
        publicPrice = _publicPrice;
    }
    
    // Set max per wallet and transaction
    function setMaxLimits(uint256 _maxPerWallet, uint256 _maxPerTransaction) external onlyOwner {
        maxPerWallet = _maxPerWallet;
        maxPerTransaction = _maxPerTransaction;
    }
    
    // Whitelist mint
    function whitelistMint(uint256 quantity, bytes32[] calldata proof) external payable {
        require(saleState == SaleState.Whitelist, "Whitelist sale not active");
        require(quantity > 0, "Must mint at least 1 NFT");
        require(quantity <= maxPerTransaction, "Exceeds max per transaction");
        require(!whitelistClaimed[msg.sender], "Whitelist already claimed");
        require(msg.value >= whitelistPrice * quantity, "Insufficient payment");
        
        // Verify merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid merkle proof");
        
        // Check supply
        uint256 supply = totalSupply();
        require(supply + quantity <= maxSupply, "Exceeds maximum supply");
        
        // Mark as claimed
        whitelistClaimed[msg.sender] = true;
        
        // Mint tokens
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, supply + i + 1);
        }
    }
    
    // Public mint
    function publicMint(uint256 quantity) external payable {
        require(saleState == SaleState.Public, "Public sale not active");
        require(quantity > 0, "Must mint at least 1 NFT");
        require(quantity <= maxPerTransaction, "Exceeds max per transaction");
        require(publicMinted[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet allocation");
        require(msg.value >= publicPrice * quantity, "Insufficient payment");
        
        // Check supply
        uint256 supply = totalSupply();
        require(supply + quantity <= maxSupply, "Exceeds maximum supply");
        
        // Update minted count
        publicMinted[msg.sender] += quantity;
        
        // Mint tokens
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, supply + i + 1);
        }
    }
    
    // Override tokenURI function to handle hidden/revealed state
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        if (!isRevealed) {
            return hiddenBaseURI;
        }
        
        return string(abi.encodePacked(revealedBaseURI, tokenId.toString(), ".json"));
    }
    
    // Owner function to reveal collection
    function revealCollection(string memory _revealedBaseURI) external onlyOwner {
        revealedBaseURI = _revealedBaseURI;
        isRevealed = true;
    }
    
    // Owner function to set royalty info
    function setRoyaltyInfo(address _receiver, uint96 _percentage) external onlyOwner {
        require(_percentage <= 10000, "Percentage cannot exceed 100%");
        royaltyReceiver = _receiver;
        royaltyPercentage = _percentage;
    }
    
    // Owner function to withdraw funds
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
    
    // Implementation of IERC2981 royaltyInfo
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(_tokenId), "Token does not exist");
        
        // Calculate royalty amount (percentage is in basis points, e.g. 500 = 5%)
        uint256 amount = (_salePrice * royaltyPercentage) / 10000;
        
        return (royaltyReceiver, amount);
    }
    
    // Override supportsInterface to declare IERC2981 support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return 
            interfaceId == type(IERC2981).interfaceId || 
            super.supportsInterface(interfaceId);
    }
}
