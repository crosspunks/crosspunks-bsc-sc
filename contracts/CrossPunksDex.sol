// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn"t hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
        return c;
    }
}

interface ERC721TokenReceiver {
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}

interface CrossPunks {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}

contract CrossPunksDex is ERC721TokenReceiver {
    struct Offer {
        bool isForSale;
        uint256 punkIndex;
        address seller;
        uint256 minValue; // in BNB
        address onlySellTo; // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint256 punkIndex;
        address bidder;
        uint256 value;
    }

    bool public marketPaused;

    address payable internal _deployer;

    IERC721 private _crosspunks;

    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(uint256 => Offer) public punksOfferedForSale;

    // A record of the highest punk bid
    mapping(uint256 => Bid) public punkBids;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event PunkTransfer(
        address indexed from,
        address indexed to,
        uint256 punkIndex
    );
    event PunkOffered(
        uint256 indexed punkIndex,
        uint256 minValue,
        address indexed toAddress
    );
    event PunkBidEntered(
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress
    );
    event PunkBidWithdrawn(
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress
    );
    event PunkBought(
        uint256 indexed punkIndex,
        uint256 value,
        address indexed fromAddress,
        address indexed toAddress
    );
    event PunkNoLongerForSale(uint256 indexed punkIndex);
    event ERC721Received(address operator, address _from, uint256 tokenId);

    modifier onlyDeployer() {
        require(msg.sender == _deployer, "Only deployer.");
        _;
    }

    bool private _reentrancyLock = false;

    /* Prevent a contract function from being reentrant-called. */
    modifier reentrancyGuard() {
        if (_reentrancyLock) {
            revert();
        }
        _reentrancyLock = true;
        _;
        _reentrancyLock = false;
    }

    constructor(address crosspunks) public {
        _deployer = msg.sender;
        _crosspunks = CrossPunks(crosspunks);
    }

    function pauseMarket(bool _paused) external onlyDeployer {
        marketPaused = _paused;
    }

    function offerPunkForSale(uint256 punkIndex, uint256 minSalePriceInBNB)
        public
        reentrancyGuard
    {
        require(marketPaused == false, "Market Paused");
        require(_crosspunks.ownerOf(punkIndex) == msg.sender, "Only owner");
        require(
            (_crosspunks.getApproved(punkIndex) == address(this) ||
                _crosspunks.isApprovedForAll(msg.sender, address(this))),
            "Not Approved"
        );

        _crosspunks.safeTransferFrom(msg.sender, address(this), punkIndex);
        punksOfferedForSale[punkIndex] = Offer(
            true,
            punkIndex,
            msg.sender,
            minSalePriceInBNB,
            address(0)
        );

        emit PunkOffered(punkIndex, minSalePriceInBNB, address(0));
    }

    function offerPunkForSaleToAddress(
        uint256 punkIndex,
        uint256 minSalePriceInBNB,
        address toAddress
    ) public reentrancyGuard {
        require(marketPaused == false, "Market Paused");
        require(_crosspunks.ownerOf(punkIndex) == msg.sender, "Only owner");
        require(
            (_crosspunks.getApproved(punkIndex) == address(this) ||
                _crosspunks.isApprovedForAll(msg.sender, address(this))),
            "Not Approved"
        );

        _crosspunks.safeTransferFrom(msg.sender, address(this), punkIndex);
        punksOfferedForSale[punkIndex] = Offer(
            true,
            punkIndex,
            msg.sender,
            minSalePriceInBNB,
            toAddress
        );

        PunkOffered(punkIndex, minSalePriceInBNB, toAddress);
    }

    function buyPunk(uint256 punkIndex) public payable reentrancyGuard {
        require(marketPaused == false, "Market Paused");

        Offer memory offer = punksOfferedForSale[punkIndex];

        require(offer.isForSale == true, "punk is not for sale"); // punk not actually for sale

        if (offer.onlySellTo != address(0) && offer.onlySellTo != msg.sender) {
            revert("you can't buy this punk");
        } // punk not supposed to be sold to this user

        require(msg.sender != offer.seller, "You can not buy your punk");
        require(msg.value >= offer.minValue, "Didn't send enough BNB"); // Didn"t send enough BNB
        require(
            address(this) == _crosspunks.ownerOf(punkIndex),
            "Seller no longer owner of punk"
        ); // Seller no longer owner of punk

        address seller = offer.seller;

        _crosspunks.safeTransferFrom(address(this), msg.sender, punkIndex);

        Transfer(seller, msg.sender, 1);

        punksOfferedForSale[punkIndex] = Offer(
            false,
            punkIndex,
            msg.sender,
            0,
            address(0)
        );

        emit PunkNoLongerForSale(punkIndex);

        (bool success, ) = address(uint160(seller)).call.value(msg.value)("");

        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );

        PunkBought(punkIndex, msg.value, seller, msg.sender);

        Bid memory bid = punkBids[punkIndex];

        if (bid.hasBid) {
            punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

            (bool success, ) = address(uint160(bid.bidder)).call.value(
                bid.value
            )("");

            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        }
    }

    function enterBidForPunk(uint256 punkIndex) public payable reentrancyGuard {
        require(marketPaused == false, "Market Paused");

        Offer memory offer = punksOfferedForSale[punkIndex];

        require(offer.isForSale == true, "punk is not for sale");
        require(offer.seller != msg.sender, "owner can not bid");
        require(msg.value > 0, "bid can not be zero");

        Bid memory existing = punkBids[punkIndex];

        require(
            msg.value > existing.value,
            "you can not bid lower than last bid"
        );

        if (existing.value > 0) {
            // Refund the failing bid
            (bool success, ) = address(uint160(existing.bidder)).call.value(
                existing.value
            )("");
            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        }

        punkBids[punkIndex] = Bid(true, punkIndex, msg.sender, msg.value);

        PunkBidEntered(punkIndex, msg.value, msg.sender);
    }

    function acceptBidForPunk(uint256 punkIndex, uint256 minPrice)
        public
        reentrancyGuard
    {
        require(marketPaused == false, "Market Paused");

        Offer memory offer = punksOfferedForSale[punkIndex];

        address seller = offer.seller;

        Bid memory bid = punkBids[punkIndex];

        require(seller == msg.sender, "Only NFT Owner");
        require(bid.value > 0, "there is not any bid");
        require(bid.value >= minPrice, "bid is lower than min price");

        _crosspunks.safeTransferFrom(address(this), bid.bidder, punkIndex);

        Transfer(seller, bid.bidder, 1);

        punksOfferedForSale[punkIndex] = Offer(
            false,
            punkIndex,
            bid.bidder,
            0,
            address(0)
        );

        punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

        (bool success, ) = address(uint160(offer.seller)).call.value(bid.value)(
            ""
        );
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );

        PunkBought(punkIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForPunk(uint256 punkIndex) public reentrancyGuard {
        Bid memory bid = punkBids[punkIndex];

        require(bid.hasBid == true, "There is not bid");
        require(bid.bidder == msg.sender, "Only bidder can withdraw");

        uint256 amount = bid.value;

        punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

        // Refund the bid money
        (bool success, ) = address(uint160(msg.sender)).call.value(amount)("");

        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );

        emit PunkBidWithdrawn(punkIndex, bid.value, msg.sender);
    }

    function punkNoLongerForSale(uint256 punkIndex) public reentrancyGuard {
        Offer memory offer = punksOfferedForSale[punkIndex];

        require(offer.isForSale == true, "punk is not for sale");

        address seller = offer.seller;

        require(seller == msg.sender, "Only Owner");

        _crosspunks.safeTransferFrom(address(this), msg.sender, punkIndex);

        punksOfferedForSale[punkIndex] = Offer(
            false,
            punkIndex,
            msg.sender,
            0,
            address(0)
        );

        Bid memory bid = punkBids[punkIndex];

        if (bid.hasBid) {
            punkBids[punkIndex] = Bid(false, punkIndex, address(0), 0);

            // Refund the bid money
            (bool success, ) = address(uint160(bid.bidder)).call.value(
                bid.value
            )("");

            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        }

        emit PunkNoLongerForSale(punkIndex);
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
