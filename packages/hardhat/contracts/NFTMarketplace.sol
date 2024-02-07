// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the required OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// NFT Marketplace contract
contract NFTMarketplace is Ownable {
    uint256 public feePercentage;  // fee percentage set by the marketplace owner

    struct NftListing {
        address nftContract;  // address of the ERC721 NFT contract
        uint256 tokenId;  // ID of the NFT token
        address seller;  // address of the NFT owner
        uint256 price;  // listing price for the NFT
        bool isListed;  // bool to check if NFT is currently listed
    }

    // Mapping to store NFT listings
    mapping(uint256 => NftListing) public nftListings;

    // Event triggered when a new NFT is listed for sale
    event NftListed(address indexed seller, address indexed buyer, address indexed collection, uint256 tokenId, uint256 price);

    // Event triggered when an NFT listing is removed
    event NftUnlisted(address indexed seller, address indexed collection, uint256 tokenId);

    // Event triggered when an NFT is sold
    event NftSold(address indexed seller, address indexed buyer, address indexed collection, uint256 tokenId, uint256 price);

    // Modifier to check if an NFT is listed for sale
    modifier isListed(uint256 tokenId) {
        require(nftListings[tokenId].isListed, "NFT is not listed for sale");
        _;
    }

    // Modifier to check if the caller is the NFT owner
    modifier isOwner(uint256 tokenId) {
        require(IERC721(nftListings[tokenId].nftContract).ownerOf(tokenId) == msg.sender, "Caller is not the NFT owner");
        _;
    }

    // Modifier to check if the caller is the NFT owner or the marketplace owner
    modifier isOwnerOrSeller(uint256 tokenId) {
        require(IERC721(nftListings[tokenId].nftContract).ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Caller is not the NFT owner or marketplace owner");
        _;
    }

    // Constructor to set the initial fee percentage
    constructor() {
        feePercentage = 5;  // default fee percentage set to 5%
    }

    // Function to list an NFT for sale
    function listNftForSale(address nftContract, uint256 tokenId, uint256 price) external isOwner(tokenId) {
        require(!nftListings[tokenId].isListed, "NFT is already listed for sale");

        // Transfer the NFT to the contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // Create a new NFT listing
        nftListings[tokenId] = NftListing({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            isListed: true
        });

        emit NftListed(msg.sender, address(this), nftContract, tokenId, price);
    }

    // Function to remove an NFT listing
    function unlistNft(uint256 tokenId) external isListed(tokenId) isOwnerOrSeller(tokenId) {
        delete nftListings[tokenId];

        // Transfer the NFT back to the NFT owner
        IERC721(nftListings[tokenId].nftContract).transferFrom(address(this), msg.sender, tokenId);

        emit NftUnlisted(msg.sender, nftListings[tokenId].nftContract, tokenId);
    }

    // Function to buy an NFT
    function buyNft(uint256 tokenId) external payable isListed(tokenId) {
        NftListing memory listing = nftListings[tokenId];

        require(msg.value >= listing.price, "Insufficient payment");

        address seller = listing.seller;
        uint256 price = listing.price;
        
        // Calculate the fee amount
        uint256 feeAmount = (price * feePercentage) / 100;

        // Transfer the payment amount to the seller (excluding the fee)
        (bool success, ) = seller.call{value: (price - feeAmount)}("");
        require(success, "Failed to transfer payment");

        // Transfer the NFT to the buyer
        IERC721(listing.nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        // Remove the NFT listing
        delete nftListings[tokenId];

        emit NftSold(seller, msg.sender, listing.nftContract, tokenId, price);
    }

    // Function to update the fee percentage by the marketplace owner
    function updateFeePercentage(uint256 newFeePercentage) external onlyOwner {
        require(newFeePercentage <= 100, "Invalid fee percentage");

        feePercentage = newFeePercentage;
    }
}