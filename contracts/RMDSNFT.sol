// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RMDSNFT is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    address contractAddress;

    constructor(address marketplaceAddress) ERC721("RMDSNFT", "RMDSNFT") {
        contractAddress = marketplaceAddress;
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
