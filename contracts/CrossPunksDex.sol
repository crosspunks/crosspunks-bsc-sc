// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract CrossPunksDex is IERC721Receiver, Ownable, ReentrancyGuard {
    struct Offer {
        bool isForSale;
        address addressCollection;
        uint256 punkIndex;
        address seller;
        uint256 minValue; // in BNB
    }

    struct Bid {
        bool hasBid;
        uint256 punkIndex;
        address bidder;
        uint256 value;
    }

    bool public marketPaused;

    IERC721 private _nftCollection;
    
    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(uint256 => Offer) public punksOfferedForSale;

    // A record of the highest punk bid
    mapping(uint256 => Bid) public punkBids;

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
        address addressCollection,
        uint256 indexed punkIndex,
        uint256 minValue
    );

    event NftBidEntered(
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
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress,
        address indexed toAddress
    );
    event NftNoLongerForSale(uint256 indexed punkIndex);

    event ERC721Received(address operator, address _from, uint256 tokenId);

    constructor(){}

    function pauseMarket(bool _paused) external onlyOwner {
        marketPaused = _paused;
    }
    // function edit status NFT collection
    function editWhiteList(address addressCollection, bool _status) external onlyOwner {
        nftColection[addressCollection] = _status;
    }

    function offerForSale(address addressCollecttion,uint256 punkIndex, uint256 minSalePriceInBNB)
        public
        nonReentrant
    {   
        IERC721 collection;
        collection = IERC721(addressCollecttion);
        require(marketPaused == false, "Market Paused");
        require(nftColection[addressCollecttion] == true, "NFT not correct");
        require(collection.ownerOf(punkIndex) == msg.sender, "Only owner");
        require(
            (collection.getApproved(punkIndex) == address(this) ||
                collection.isApprovedForAll(msg.sender, address(this))),
            "Not Approved"
        );

        collection.safeTransferFrom(msg.sender, address(this), punkIndex);
        punksOfferedForSale[punkIndex] = Offer(
            true,
            addressCollecttion,
            punkIndex,
            msg.sender,
            minSalePriceInBNB
        );

        emit Offered(addressCollecttion, punkIndex, minSalePriceInBNB);
    }

    function buyPunk(address addressCollecttion, uint256 punkIndex) public payable nonReentrant {
        require(marketPaused == false, "Market Paused");

        IERC721 collection;
        collection = IERC721(addressCollecttion);
        require(nftColection[addressCollecttion], "NFT not correct");

        Offer memory offer = punksOfferedForSale[punkIndex];

        require(offer.isForSale == true, "punk is not for sale"); // punk not actually for sale
        require(msg.sender != offer.seller, "You can not buy your punk");
        require(msg.value >= offer.minValue, "Didn't send enough BNB"); // Didn"t send enough BNB
        require(
            address(this) == collection.ownerOf(punkIndex),
            "Seller no longer owner of punk"
        ); // Seller no longer owner of punk

        address seller = offer.seller;

        collection.safeTransferFrom(address(this), msg.sender, punkIndex);

        emit Transfer(seller, msg.sender, 1);

        punksOfferedForSale[punkIndex] = Offer(
            false,
            addressCollecttion,
            punkIndex,
            msg.sender,
            0
        );

        // emit NftNoLongerForSale(punkIndex);

        // Bid memory bid = punkBids[punkIndex];

        // if (bid.hasBid) {
        //     punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

        //     (bool success, ) = address(uint160(bid.bidder)).call{ value: bid.value }("");
        //     require(
        //         success,
        //         "Address: unable to send value, recipient may have reverted"
        //     );
        // }

        (bool success, ) = seller.call{ value: msg.value }("");

        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );

        emit NftBought(punkIndex, msg.value, seller, msg.sender);
    }

    // function enterBidForPunk(uint256 punkIndex) public payable nonReentrant {
    //     require(marketPaused == false, "Market Paused");

    //     Offer memory offer = punksOfferedForSale[punkIndex];

    //     require(offer.isForSale == true, "punk is not for sale");
    //     require(offer.seller != msg.sender, "owner can not bid");
    //     require(msg.value > 0, "bid can not be zero");

    //     Bid memory existing = punkBids[punkIndex];

    //     require(
    //         msg.value > existing.value,
    //         "you can not bid lower than last bid"
    //     );

    //     punkBids[punkIndex] = Bid(true, punkIndex, msg.sender, msg.value);

    //     if (existing.value > 0) {
    //         // Refund the failing bid
    //         (bool success, ) = address(uint160(existing.bidder)).call{ value: existing.value }("");
    //         require(
    //             success,
    //             "Address: unable to send value, recipient may have reverted"
    //         );
    //     }

    //     emit NftBidEntered(punkIndex, msg.value, msg.sender);
    // }

    // function acceptBidForPunk(uint256 punkIndex, uint256 minPrice)
    //     public
    //     nonReentrant
    // {
    //     require(marketPaused == false, "Market Paused");

    //     Offer memory offer = punksOfferedForSale[punkIndex];

    //     address seller = offer.seller;

    //     Bid memory bid = punkBids[punkIndex];

    //     require(seller == msg.sender, "Only NFT Owner");
    //     require(bid.value > 0, "there is not any bid");
    //     require(bid.value >= minPrice, "bid is lower than min price");

    //     _nftCollection.safeTransferFrom(address(this), bid.bidder, punkIndex);

    //     emit Transfer(seller, bid.bidder, 1);

    //     punksOfferedForSale[punkIndex] = Offer(
    //         false,
    //         punkIndex,
    //         bid.bidder,
    //         0,
    //         address(0)
    //     );

    //     punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

    //     (bool success, ) = address(uint160(offer.seller)).call{ value: bid.value }("");
    //     require(
    //         success,
    //         "Address: unable to send value, recipient may have reverted"
    //     );

    //     emit NftBought(punkIndex, bid.value, seller, bid.bidder);
    // }

    // function withdrawBidForPunk(uint256 punkIndex) public nonReentrant {
    //     Bid memory bid = punkBids[punkIndex];

    //     require(bid.hasBid == true, "There is not bid");
    //     require(bid.bidder == msg.sender, "Only bidder can withdraw");

    //     uint256 amount = bid.value;

    //     punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

    //     // Refund the bid money
    //     (bool success, ) = address(uint160(msg.sender)).call{ value: amount }("");

    //     require(
    //         success,
    //         "Address: unable to send value, recipient may have reverted"
    //     );

    //     emit NftBidWithdrawn(punkIndex, bid.value, msg.sender);
    // }

    // function punkNoLongerForSale(uint256 punkIndex) public nonReentrant {
    //     Offer memory offer = punksOfferedForSale[punkIndex];

    //     require(offer.isForSale == true, "punk is not for sale");

    //     address seller = offer.seller;

    //     require(seller == msg.sender, "Only Owner");

    //     _nftCollection.safeTransferFrom(address(this), msg.sender, punkIndex);

    //     punksOfferedForSale[punkIndex] = Offer(
    //         false,
    //         punkIndex,
    //         msg.sender,
    //         0,
    //         address(0)
    //     );

    //     Bid memory bid = punkBids[punkIndex];

    //     if (bid.hasBid) {
    //         punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

    //         // Refund the bid money
    //         (bool success, ) = address(uint160(bid.bidder)).call{ value: bid.value }("");

    //         require(
    //             success,
    //             "Address: unable to send value, recipient may have reverted"
    //         );
    //     }

    //     emit NftNoLongerForSale(punkIndex);
    // }

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
