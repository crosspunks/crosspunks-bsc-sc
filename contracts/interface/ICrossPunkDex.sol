// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


interface ICrossPunkDex {
    
    struct Offer {
        bool isForSale;
        address seller;
        uint256 minValue; // in CST
    }

    event NftTransfer(
        address addressCollection,
        address indexed from,
        address indexed to,
        uint256 nftId
    );
    event Offered(
        address indexed addressCollection,
        uint256 indexed nftId,
        uint256 minValue
    );

    event NftBought(
        address indexed addressCollection,
        uint256 indexed nftId,
        uint256 value,
        address fromAddress,
        address indexed toAddress
    );

    event NftNoLongerForSale(uint256 indexed nftId);

    event ERC721Received(address operator, address _from, uint256 tokenId);

    function pauseMarket(bool _paused) external;

    // function edit status NFT collection
    function editWhiteList(address addressCollection, bool _status) external;

    function editPriceNft(address addressCollection, uint256 nftId, uint256 price) external;

    function offerForSale(address addressCollection,uint256 nftId, uint256 minSaleCST) external;

    function buyNft(address addressCollection, uint256 nftId) external;

    function withdrawNft(address addressCollection, uint256 nftId) external;

    function comissionToOwner() external;
}