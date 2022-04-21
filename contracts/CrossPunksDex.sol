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

    bool public marketPaused;

    // A record of punks that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping(address => mapping(uint256 => Offer)) public punksOfferedForSale;

    IERC20 private _tokenSale;

    //White list NFT collection 
    mapping(address => bool) public nftColection;

    event NftTransfer(
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

    modifier pause(address addressCollection){
        require(marketPaused == false, "Market Paused");
        require(nftColection[addressCollection] == true, "NFT not correct");
        _;
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
        pause(addressCollection)
    {   
        IERC721 collection = IERC721(addressCollection);
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

    function buyNft(address addressCollection, uint256 punkIndex) public payable nonReentrant pause(addressCollection) {

        IERC721 collection = IERC721(addressCollection);

        Offer memory offer = punksOfferedForSale[addressCollection][punkIndex];

        require(offer.isForSale == true, "punk is not for sale"); // punk not actually for sale
        require(msg.sender != offer.seller, "You can not buy your punk");
        require(_tokenSale.balanceOf(msg.sender) >= offer.minValue, "Didn't send enough CST"); // Didn"t send enough CST
        require(
            address(this) == collection.ownerOf(punkIndex),
            "Seller no longer owner of punk"
        ); 

        address seller = offer.seller;
        
        collection.safeTransferFrom(address(this), msg.sender, punkIndex);
        _tokenSale.safeTransferFrom(msg.sender, address(this), offer.minValue);
        _tokenSale.safeTransfer(seller, offer.minValue * 95 / 100);
        
        emit NftTransfer(addressCollection, seller, msg.sender, punkIndex);

        punksOfferedForSale[addressCollection][punkIndex] = Offer(
            false,
            msg.sender,
            0
        );

        emit NftBought(addressCollection, punkIndex, offer.minValue, seller, msg.sender);
    }

    function withdrawNft(address addressCollection, uint256 punkIndex) public nonReentrant {
        
        IERC721 collection = IERC721(addressCollection);
        require(nftColection[addressCollection], "NFT not correct");
        
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
