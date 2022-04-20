// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract CrossPunksDex is IERC721Receiver, Ownable, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    struct Offer {
        bool isForSale;
        address seller;
        uint256 minValue; // in CST
    }

    struct Bid {
        bool hasBid;
        address bidder;
        uint256 value;
    }
    
    bool public marketPaused;

    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(address => mapping(uint256 => Offer)) public punksOfferedForSale;

    IERC20 private _tokenSale;
    // A record of the highest punk bid
    mapping(address => mapping (uint256 => Bid)) public punkBids;

    //White list NFT collection 
    mapping(address => bool) public nftColection;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event PunkTransfer(
        address addressCollection,
        address indexed from,
        address indexed to,
        uint256 punkIndex
    );
    event Offered(
        address indexed addressCollection,
        uint256 indexed punkIndex,
        uint256 minValue
    );

    event NftBidEntered(
        address indexed addressCollection,
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress
    );
    event NftBidWithdrawn(
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress
    );
    event NftBought(
        address indexed addressCollection,
        uint256 indexed punkIndex,
        uint256 value,
        address fromAddress,
        address indexed toAddress
    );
    event NftNoLongerForSale(uint256 indexed punkIndex);

    event ERC721Received(address operator, address _from, uint256 tokenId);

    constructor(address tokenAddress){
        _tokenSale = IERC20(tokenAddress);
    }

    function pauseMarket(bool _paused) external onlyOwner {
        marketPaused = _paused;
    }
    // function edit status NFT collection
    function editWhiteList(address addressCollection, bool _status) external onlyOwner {
        nftColection[addressCollection] = _status;
    }

    function offerForSale(address addressCollection,uint256 punkIndex, uint256 minSaleCST)
        public
        nonReentrant
    {   
        IERC721 collection;
        collection = IERC721(addressCollection);
        require(marketPaused == false, "Market Paused");
        require(nftColection[addressCollection] == true, "NFT not correct");
        require(collection.ownerOf(punkIndex) == msg.sender, "Only owner");
        require(
            (collection.getApproved(punkIndex) == address(this) ||
                collection.isApprovedForAll(msg.sender, address(this))),
            "Not Approved"
        );

        collection.safeTransferFrom(msg.sender, address(this), punkIndex);
        punksOfferedForSale[addressCollection][punkIndex] = Offer(
            true,
            msg.sender,
            minSaleCST
        );

        emit Offered(addressCollection, punkIndex, minSaleCST);
    }

    function buyPunk(address addressCollection, uint256 punkIndex) public payable nonReentrant {
        require(marketPaused == false, "Market Paused");

        IERC721 collection;
        collection = IERC721(addressCollection);
        require(nftColection[addressCollection], "NFT not correct");

        Offer memory offer = punksOfferedForSale[addressCollection][punkIndex];

        require(offer.isForSale == true, "punk is not for sale"); // punk not actually for sale
        require(msg.sender != offer.seller, "You can not buy your punk");
        require(_tokenSale.balanceOf(msg.sender) >= offer.minValue, "Didn't send enough CST"); // Didn"t send enough CST
        require(
            address(this) == collection.ownerOf(punkIndex),
            "Seller no longer owner of punk"
        ); // Seller no longer owner of punk

        address seller = offer.seller;
        
        collection.safeTransferFrom(address(this), msg.sender, punkIndex);

        emit Transfer(seller, msg.sender, 1);

        punksOfferedForSale[addressCollection][punkIndex] = Offer(
            false,
            msg.sender,
            0
        );

        emit NftNoLongerForSale(punkIndex);

        Bid memory bid = punkBids[addressCollection][punkIndex];

        if (bid.hasBid) {
            punkBids[addressCollection][punkIndex] = Bid(false, address(0), 0);
            _tokenSale.safeTransfer(seller, offer.minValue * 95 / 100);
        }

        _tokenSale.safeTransferFrom(msg.sender, address(this), offer.minValue);
        _tokenSale.safeTransfer(seller, offer.minValue * 95 / 100);

        emit NftBought(addressCollection, punkIndex, offer.minValue, seller, msg.sender);
    }

    function enterBidForPunk(address addressCollection, uint256 punkIndex, uint256 tokenBid) public payable nonReentrant {
    
        IERC721 collection;
        collection = IERC721(addressCollection);

        require(marketPaused == false, "Market Paused");

        Offer memory offer = punksOfferedForSale[addressCollection][punkIndex];

        require(offer.isForSale == true, "punk is not for sale");
        require(offer.seller != msg.sender, "owner can not bid");
        require(tokenBid >= offer.minValue, "Didn't send enough CST"); // Didn"t send enough CST
        require(_tokenSale.balanceOf(msg.sender) >= tokenBid, "");
        Bid memory existing = punkBids[addressCollection][punkIndex];

        require(
            tokenBid > existing.value,
            "you can not bid lower than last bid"
        );

        punkBids[addressCollection][punkIndex] = Bid(true, msg.sender, tokenBid);

        if (existing.value > 0) {
            // Refund the failing bid
            _tokenSale.safeTransfer(existing.bidder, existing.value);
            
        }
        _tokenSale.safeTransferFrom(msg.sender, address(this), tokenBid);

        emit NftBidEntered(addressCollection, punkIndex, tokenBid, msg.sender);
    }

    function acceptBidForPunk(address addressCollection, uint256 punkIndex)
        public
        nonReentrant
    {
        
        require(marketPaused == false, "Market Paused");

        Offer memory offer = punksOfferedForSale[addressCollection][punkIndex];

        address seller = offer.seller;

        Bid memory bid = punkBids[addressCollection][punkIndex];

        require(seller == msg.sender, "Only NFT Owner");
        require(bid.value > 0, "there is not any bid");
        require(bid.value >= offer.minValue, "bid is lower than min price");

        IERC721 collection;
        collection = IERC721(addressCollection);

        collection.safeTransferFrom(address(this), bid.bidder, punkIndex);
        _tokenSale.safeTransfer(msg.sender, bid.value);

        punksOfferedForSale[addressCollection][punkIndex] = Offer(
            false,
            bid.bidder,
            0
        );

        punkBids[addressCollection][punkIndex] = Bid(false, address(0), 0);

        emit NftBought(addressCollection, punkIndex, bid.value, seller, bid.bidder);
    }

    function punkNoLongerForSale(address addressCollection, uint256 punkIndex) public nonReentrant {
        
        IERC721 collection = IERC721(addressCollection);
        
        Offer memory offer = punksOfferedForSale[addressCollection][punkIndex];

        require(offer.isForSale == true, "punk is not for sale");

        address seller = offer.seller;

        require(seller == msg.sender, "Only Owner");

        collection.safeTransferFrom(address(this), msg.sender, punkIndex);

        punksOfferedForSale[addressCollection][punkIndex] = Offer(
            false,
            msg.sender,
            0
        );

        Bid memory bid = punkBids[addressCollection][punkIndex];

        if (bid.hasBid) {
            punkBids[addressCollection][punkIndex] = Bid(false, address(0), 0);

            // Refund the bid money
            _tokenSale.safeTransfer(bid.bidder, bid.value);
        }

        emit NftNoLongerForSale(punkIndex);
    }

    function comissionToOwner() external onlyOwner {
        _tokenSale.safeTransfer(owner(), _tokenSale.balanceOf(address(this)));
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external override returns (bytes4) {
        _data;
        emit ERC721Received(_operator, _from, _tokenId);
        return 0x5175f878;
    }
}
