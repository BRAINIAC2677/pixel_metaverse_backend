# Pixel Metaverse Backend
<img src="assets/pixel_metaverse.png" height = auto width = 700>
<br/>

## Deployment:
- Sepolia Testnet
- ArtworkToken Contract Transaction Hash [Etherscan Ref](https://sepolia.etherscan.io/address/0xFe58726115AF6267516eBaD2164cce870D2fFDA0)
- Marketplace Contract Transaction Hash [Etherscan Ref](https://sepolia.etherscan.io/address/0x9F7198B00adaa0DB035F75C94C7946b1c3be73bf)

## Features:
    - Auction
    - Royalty
    - Track Order
    - Fee split
    - Artwork verification
    - Artwork Tokenization by ERC721

## Tech Stack:
    - Solidity
    - Sepolia Testnet
    - Remix
    - IPFS
## Public function from smart contract:
- ### Artist/Seller
    - function register_artist(
        string memory _name,
        string memory _img_ipfs_hash
    ) public 
    - function login_artist() public view returns (Artist memory) 
    - function add_artwork(
        uint256 _price,
        uint256 _count,
        string memory _description,
        string memory _img_ipfs_hash
    ) public 
    - function request_verification(uint256 _original_artwork_id) public
 
- ### Buyer
    - function buy_artwork(
        uint256 _artwork_id,
        string memory _shipping_address
    ) public payable 
    - function delivery_confirmation(uint256 _order_id) public

- ### Verifier
    - function register_verifier() public 
    - function get_verification_requests()
        public
        view
        returns (OriginalArtwork[] memory)
    - function verify_artwork(uint256 _original_artwork_id) public

- ### Auction 
    - function put_up_for_auction(uint256 _artwork_id, uint256 _min_bid) public 
    - function bid(uint256 _auction_item_id) public payable  
    - function end_auction_seller(uint256 _auction_item_id) public 
    - function end_auction_buyer(uint256 _auction_item_id) public 

- ### Retrieve Informations
    - function get_original_artworks() public view returns (OriginalArtwork[] memory) 
    - function get_artists() public view returns (Artist[] memory) 
    - function get_artworks() public view returns (Artwork[] memory) 
    - function get_auction_items() public view returns (AuctionItem[] memory)  
  