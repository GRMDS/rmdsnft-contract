// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RMDSNFT is ERC721, ReentrancyGuard, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _tokenIdCounter;
    address contractAddress;
    address private _systemAddress;
    mapping(string => bool) public _usedNonces;

    constructor(address marketplaceAddress) ERC721("RMDSNFT", "RMDSNFT") {
        contractAddress = marketplaceAddress;
    }

    function whitelistMint(string memory uri, string memory nonce, bytes32 hash, bytes memory signature) external payable nonReentrant {
        require(matchSigner(hash, signature), "Please mint only through the website");
        require(!_usedNonces[nonce], "You cannot reuse a hash");
        require(hashTransaction(msg.sender, uri, nonce) == hash, "Incorrect Hash");

        _usedNonces[nonce] = true;
        safeMint(uri);
    }

    function matchSigner(bytes32 hash, bytes memory signature) public view returns (bool) {
        return _systemAddress == hash.toEthSignedMessageHash().recover(signature);
    }

    function hashTransaction(address sender, string memory uri, string memory nonce) public view returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(sender, uri, nonce, address(this)));
        return hash;
    }

    event NFTMinted(
        address indexed marketplaceContract,
        uint indexed tokenId,
        address owner,
        string tokenURI
    );

    function safeMint(string memory uri) public payable {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
        setApprovalForAll(contractAddress, true);

        emit NFTMinted(
            contractAddress,
            tokenId,
            msg.sender,
            uri
        );
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
