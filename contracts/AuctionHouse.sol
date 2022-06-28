// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AuctionHouse is ERC721Holder, Ownable {
    address public feeAddress;
    uint16 public feePercent;

    /// @param _feeAddress must be either an EOA or a contract must have payable receive func and doesn't have some codes in that func.
    /// If not, it might be that it won't be receive any fee.
    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeePercent(uint16 _percent) external onlyOwner {
        require(_percent <= 10000, "input value is more than 100%");
        feePercent = _percent;
    }

    struct Auction {
        IERC721 token;
        uint256 tokenId;
        uint8 auctionType;  // 0: Fixed Price, 1: Dutch Auction, 2: English Auction
        uint256 startPrice;
        uint256 endPrice;
        uint256 startBlock;
        uint256 endBlock;
        uint256 lastBidPrice;
        address seller;
        address lastBidder;
        bool isSold;
    }

    mapping (IERC721 => mapping (uint256 => bytes32[])) public auctionIdByToken;
    mapping (address => bytes32[]) public auctionIdBySeller;
    mapping (bytes32 => Auction) public auctionInfo;
    mapping (address => uint) public bids;

    event AuctionCreated(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address seller);
    event ListingCreated(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address seller);
    event AuctionCanceled(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address seller);
    event BidPlaced(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address bidder, uint256 bidPrice);
    event TokenClaimed(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address seller, address buyer, uint256 price);
    event WithdrawBid(IERC721 indexed token, uint256 id, bytes32 indexed auctionId, address bidder, uint256 bidPrice);

    constructor(uint16 _feePercent) {
        require(_feePercent <= 10000, "The input value cannot be more than 100%");
        feeAddress = payable(msg.sender);
        feePercent = _feePercent;
    }

    function getCurrentPrice(bytes32 _auction) public view returns (uint256) {
        Auction storage a = auctionInfo[_auction];
        uint8 auctionType = a.auctionType;
        if (auctionType == 0) {
            return a.startPrice;
        } else if (auctionType == 2) {  // English Auction
            uint256 lastBidPrice = a.lastBidPrice;
            return lastBidPrice == 0 ? a.startPrice : lastBidPrice;
        } else {
            uint256 _startPrice = a.startPrice;
            uint256 _startBlock = a.startBlock;
            uint256 tickPerBlock = (_startPrice - a.endPrice) / (a.endBlock - _startBlock);
            return _startPrice - ((block.number - _startBlock) * tickPerBlock);
        }
    }

    function _auctionId(IERC721 _token, uint256 _id, address _seller) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.number, _token, _id, _seller));
    }

    function _createAuction(
        uint8 _auctionType,
        IERC721 _token,
        uint256 _id,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _endBlock
    ) internal {
        require(_endBlock > block.number, "Duration must be a positive value in the future");

        // push
        bytes32 auctionId = _auctionId(_token, _id, msg.sender);
        auctionInfo[auctionId] = Auction(_token, _id, _auctionType, _startPrice, _endPrice, block.number, _endBlock, 0, msg.sender, address(0), false);
        auctionIdByToken[_token][_id].push(auctionId);
        auctionIdBySeller[msg.sender].push(auctionId);

        // check if seller has a right to transfer the NFT token.
        _token.safeTransferFrom(msg.sender, address(this), _id);

        if (_auctionType == 0) {
            emit ListingCreated(_token, _id, auctionId, msg.sender);
        } else {
            emit AuctionCreated(_token, _id, auctionId, msg.sender);
        }
    }

    // 0: Fixed Price
    function fixedPrice(IERC721 _token, uint256 _id, uint256 _price, uint256 _endBlock) public {
        _createAuction(0, _token, _id, _price, 0, _endBlock); // endPrice = 0 for saving gas
    }

    // 1: Dutch Auction,
    function dutchAuction(IERC721 _token, uint256 _id, uint256 _startPrice, uint256 _endPrice, uint256 _endBlock) public {
        require(_startPrice > _endPrice, "End price should be lower than start price");
        _createAuction(1, _token, _id, _startPrice, _endPrice, _endBlock); // startPrice != endPrice
    }

    // 2: English Auction
    function englishAuction(IERC721 _token, uint256 _id, uint256 _startPrice, uint256 _endBlock) public {
        _createAuction(2, _token, _id, _startPrice, 0, _endBlock); // endPrice = 0 for saving gas
    }

    function cancelAuction(bytes32 _auction) external {
        Auction storage a = auctionInfo[_auction];
        require(a.seller == msg.sender, "Access denied");
        require(a.lastBidPrice == 0, "You cannot cancel the auction since one or more bids already exist"); // for EA. but even in DA, FP, seller can withdraw their token with this func.
        require(a.isSold == false, "Item is already sold");

        IERC721 token = a.token;
        uint256 tokenId = a.tokenId;
        
        // endBlock = 0 means the auction was canceled.
        a.endBlock = 0;

        token.safeTransferFrom(address(this), msg.sender, tokenId);
        emit AuctionCanceled(token, tokenId, _auction, msg.sender);
    }

    function buyInstantly(bytes32 _auction) payable external {
        Auction storage a = auctionInfo[_auction];
        uint256 endBlock = a.endBlock;
        require(endBlock != 0, "The Auction is canceled");
        require(endBlock > block.number, "The auction has ended");
        require(a.auctionType < 2, "You cannot buy instantly in an English Auction");
        require(a.isSold == false, "The item is already sold");

        uint256 currentPrice = getCurrentPrice(_auction);
        require(msg.value >= currentPrice, "The price value supplied doesn't match with the current price");

        // reentrancy proof
        a.isSold = true;

        uint256 fee = currentPrice * feePercent / 10000;
        payable(a.seller).transfer(currentPrice - fee);
        payable(feeAddress).transfer(fee);
        if (msg.value > currentPrice) {
            payable(msg.sender).transfer(msg.value - currentPrice);
        }

        a.token.safeTransferFrom(address(this), msg.sender, a.tokenId);

        emit TokenClaimed(a.token, a.tokenId, _auction, a.seller, msg.sender, currentPrice);
    }
  
    // bid function
    // you have to pay only ETH for bidding and buying.

    // In this contract, since send function is used instead of transfer or low-level call function,
    // if a participant is a contract, it must have receive payable function.
    // But if it has some code in either receive or fallback func, they might not be able to receive their ETH.
    // Even though some contracts can't receive their ETH, the transaction won't be failed.

    // Bids must be at least 1% higher than the previous bid.
    // If someone bids in the last 5 minutes of an auction, the auction will automatically extend by 5 minutes.
    function bid(bytes32 _auction) payable external {
        Auction storage a = auctionInfo[_auction];
        uint256 endBlock = a.endBlock;
        uint256 lastBidPrice = a.lastBidPrice;
        address lastBidder = a.lastBidder;

        require(a.auctionType == 2, "Bidding is supported only in english auction");
        require(endBlock != 0, "The auction is canceled");
        require(block.number <= endBlock, "The auction has ended");
        require(a.seller != msg.sender, "You cannot bid in your own auction");

        // Bid / price increment restrictions
        if (lastBidPrice != 0) {
            require(msg.value >= lastBidPrice + (lastBidPrice / 100), "The bid must be at least 1% higher than the last bid");  // 1%
        } else {
            require(msg.value >= a.startPrice && msg.value > 0, "The bid must be higher than the start price");
        }

        // 20 blocks = 5 mins in Ethereum.
        if (block.number > endBlock - 20) {
            a.endBlock = endBlock + 20;
        }

        a.lastBidder = msg.sender;
        a.lastBidPrice = msg.value;
        bids[a.lastBidder] += a.lastBidPrice;

        if (lastBidPrice != 0) {
            payable(lastBidder).transfer(lastBidPrice);
        }
        
        emit BidPlaced(a.token, a.tokenId, _auction, msg.sender, msg.value);
    }

    // Use this to withdraw your bids from an ongoing auction.
    function withdrawBid(bytes32 _auction) external {
        Auction storage a = auctionInfo[_auction];
        require(a.auctionType != 0, "You can only call withdraw in an auction");

        address bidder = msg.sender;
        uint bidAmount = bids[bidder];
        require(bidAmount > 0, "Insufficient balance to withdraw");

        if (a.isSold != true) {
            if (bidder == a.lastBidder) {
                bidAmount -= a.lastBidPrice;
                require(bidAmount > 0 && bidAmount < a.lastBidPrice, "You cannot withdraw your highest bid");
            }
        }

        payable(bidder).transfer(bidAmount);
        bids[bidder] = 0;
        emit WithdrawBid(a.token, a.tokenId, _auction, bidder, bidAmount);     
    }

    // both seller and buyer can call this func in English Auction. Probably the buyer (last bidder) might call this func.
    // In both DA and FP, buyInstantly func include claim func.
    function claim(bytes32 _auction) external {
        Auction storage a = auctionInfo[_auction];
        address seller = a.seller;
        address lastBidder = a.lastBidder;

        require(a.isSold == false, "Item is already sold");
        require(seller == msg.sender || lastBidder == msg.sender, "You cannot claim this auction as you are neither the seller nor the highest bidder");
        require(a.auctionType == 2, "You can only claim in an English Auction");
        require(block.number > a.endBlock, "You cannot claim when the auction is still running");

        IERC721 token = a.token;
        uint256 tokenId = a.tokenId;
        uint256 lastBidPrice = a.lastBidPrice;
        uint256 fee = lastBidPrice * feePercent / 10000;

        payable(seller).transfer(lastBidPrice - fee);
        payable(feeAddress).transfer(fee);
        token.safeTransferFrom(address(this), lastBidder, tokenId);

        a.isSold = true;
        bids[lastBidder] -= lastBidPrice;

        emit TokenClaimed(token, tokenId, _auction, seller, lastBidder, lastBidPrice);
    }
}
