// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ArtworkToken.sol";

contract Marketplace is AccessControl {
    using Counters for Counters.Counter;

    ArtworkToken artwork_token;
    address payable staking_address;

    Counters.Counter private _artwork_tokenid_counter;
    Counters.Counter private _original_artwork_id_counter;
    Counters.Counter private _order_id_counter;
    Counters.Counter private _auction_item_id_counter;

    constructor(address _artwork_contract) public payable {
        artwork_token = ArtworkToken(_artwork_contract);
        staking_address = payable(address(this));
    }

    // ------------- roles -----------------
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // ------------- data structures -------------
    enum OrderStatus {
        READY_FOR_SHIPPING,
        SHIPPED,
        DELIVERED
    }

    struct Artist {
        address artist_address;
        string name;
        string img_ipfs_hash;
    }

    struct Artwork {
        bool is_for_sale;
        uint256 token_id;
        uint256 original_artwork_id;
        uint256 price;
    }

    struct OriginalArtwork {
        bool is_verified;
        uint256 original_artwork_id;
        uint256 count;
        address payable artist_address;
        string description;
        string img_ipfs_hash;
    }

    struct Order {
        uint256 order_id;
        uint256 artwork_token_id;
        address buyer_address;
        OrderStatus status;
        string shipping_address;
    }

    struct AuctionItem{
        uint256 auction_item_id;
        uint256 artwork_token_id;
        uint256 start_time;
        uint256 end_time;
        uint256 min_bid;
        uint256 highest_bid;
        address payable highest_bidder;
    }

    Artist[] artists;
    Artwork[] artworks;
    OriginalArtwork[] original_artworks;
    AuctionItem[] auction_items;

    address[] verifiers;
    uint256[] verification_requests; // contains original artwork ids for which verification is requested
    Order[] orders;
    mapping(address => uint256[]) artwork_collections;


    // -------------- public functions ------------------
    function register_artist(
        string memory _name,
        string memory _img_ipfs_hash
    ) public {
        require(
            !hasRole(ARTIST_ROLE, msg.sender),
            "Caller is already an artist"
        );
        _setupRole(ARTIST_ROLE, msg.sender);
        Artist memory new_artist = Artist({
            artist_address: msg.sender,
            name: _name,
            img_ipfs_hash: _img_ipfs_hash
        });
        artists.push(new_artist);
    }

    function login_artist() public view returns (Artist memory) {
        require(hasRole(ARTIST_ROLE, msg.sender), "Caller is not an artist");
        for (uint256 i = 0; i < artists.length; i++) {
            if (artists[i].artist_address == msg.sender) {
                return artists[i];
            }
        }
    }

    function register_verifier() public {
        require(
            !hasRole(VERIFIER_ROLE, msg.sender),
            "Caller is already a verifier"
        );
        _setupRole(VERIFIER_ROLE, msg.sender);
        verifiers.push(msg.sender);
    }

    function get_verification_requests()
        public
        view
        returns (OriginalArtwork[] memory)
    {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        OriginalArtwork[]
            memory verification_requests_artworks = new OriginalArtwork[](
                verification_requests.length
            );
        for (uint256 i = 0; i < verification_requests.length; i++) {
            verification_requests_artworks[i] = original_artworks[
                verification_requests[i]
            ];
        }
        return verification_requests_artworks;
    }

    function get_original_artworks() public view returns (OriginalArtwork[] memory) {
        return original_artworks;
    }

    function get_artists() public view returns (Artist[] memory) {
        return artists;
    }

    function get_artworks() public view returns (Artwork[] memory) {
        return artworks;
    }

    function get_auction_items() public view returns (AuctionItem[] memory) {
        return auction_items;
    }

    function get_orders() public view returns (Order[] memory) {
        return orders;
    }

    function add_artwork(
        uint256 _price,
        uint256 _count,
        string memory _description,
        string memory _img_ipfs_hash
    ) public {
        require(hasRole(ARTIST_ROLE, msg.sender), "Caller is not an artist");
        uint256 original_artwork_id = add_original_artwork(
            payable(msg.sender),
            _description,
            _img_ipfs_hash
        );
        mint_artwork(msg.sender, original_artwork_id, _count, _price);
    }

    function increae_artwork_count(
        uint256 _original_artwork_id,
        uint256 _price,
        uint256 _increase
    ) public {
        require(
           _original_artwork_id < _original_artwork_id_counter.current() && original_artworks[_original_artwork_id].artist_address ==
                msg.sender,
            "Caller is not the owner of the artwork"
        );
        mint_artwork(msg.sender, _original_artwork_id, _increase, _price);
    }

    function request_verification(uint256 _original_artwork_id) public {
        require(
            original_artworks[_original_artwork_id].artist_address ==
                msg.sender,
            "Caller is not the owner of the artwork"
        );
        require(
            !original_artworks[_original_artwork_id].is_verified,
            "OriginalArtwork is already verified"
        );
        verification_requests.push(_original_artwork_id);
    }

    function verify_artwork(uint256 _original_artwork_id) public {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        require(
            !original_artworks[_original_artwork_id].is_verified,
            "OriginalArtwork is already verified"
        );
        original_artworks[_original_artwork_id].is_verified = true;
        for (uint256 i = 0; i < verification_requests.length; i++) {
            if (verification_requests[i] == _original_artwork_id) {
                verification_requests[i] = verification_requests[
                    verification_requests.length - 1
                ];
                verification_requests.pop();
                break;
            }
        }
    }

   function buy_artwork(
        uint256 _artwork_id,
        string memory _shipping_address
    ) public payable {
        require(
            _artwork_id < _artwork_tokenid_counter.current(),
            "Artwork does not exist"
        );
        require(
            artworks[_artwork_id].is_for_sale,
            "Artwork is not for sale"
        );
        require(
            artworks[_artwork_id].price <= msg.value,
            "Incorrect amount sent"
        );

        // 30% of the price goes to the artist and 70% goes to the staking address
        payable(artwork_token.ownerOf(_artwork_id)).transfer(
           (artworks[_artwork_id].price * 30) / 100
        );
       payable(staking_address).transfer(
            artworks[_artwork_id].price -
                (artworks[_artwork_id].price * 30) /
                100
        );

        artworks[_artwork_id].is_for_sale = false;

        Order memory new_order = Order({
            order_id: _order_id_counter.current(),
            artwork_token_id: _artwork_id,
            buyer_address: msg.sender,
            status: OrderStatus.READY_FOR_SHIPPING,
            shipping_address: _shipping_address
        });
        _order_id_counter.increment();
        orders.push(new_order);
    }

    function started_shipping(uint256 _order_id) public {
        require(
            artwork_token.ownerOf(orders[_order_id].artwork_token_id) == msg.sender,
            "Caller is not the artist"
        );
        orders[_order_id].status = OrderStatus.SHIPPED;
    }

    function delivery_confirmation(uint256 _order_id) public {
        require(
            orders[_order_id].buyer_address == msg.sender,
            "Caller is not the buyer"
        );

        // transferring the  68% of the price to the seller and 2% to the original artist
        orders[_order_id].status = OrderStatus.DELIVERED;
       payable(artwork_token.ownerOf(orders[_order_id].artwork_token_id)).transfer(
               (artworks[orders[_order_id].artwork_token_id].price * 68) /
                100
       );
       address payable royalty_address = original_artworks[artworks[orders[_order_id].artwork_token_id].original_artwork_id].artist_address;
         royalty_address.transfer(
                (artworks[orders[_order_id].artwork_token_id].price * 2) /
                 100
          );

        // transferring the artwork ownership to the buyer
        artwork_token.safeTransferFrom(
            artwork_token.ownerOf(orders[_order_id].artwork_token_id),
            orders[_order_id].buyer_address,
            orders[_order_id].artwork_token_id
        );

        // removing the order from the orders array
        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].order_id == _order_id) {
                orders[i] = orders[orders.length - 1];
                orders.pop();
                break;
            }
        }
    }

    function put_up_for_auction(uint256 _artwork_id, uint256 _min_bid) public {
        require(
            artwork_token.ownerOf(_artwork_id) == msg.sender,
            "Caller is not the owner of the artwork"
        );
        require(
            artworks[_artwork_id].is_for_sale,
            "Artwork is already for sale"
        );
        artworks[_artwork_id].is_for_sale = false;
        auction_items.push(AuctionItem({
            auction_item_id: _auction_item_id_counter.current(),
            artwork_token_id: _artwork_id,
            start_time: block.timestamp,
            end_time: block.timestamp + 1 weeks,
            min_bid: _min_bid,
            highest_bid: 0,
            highest_bidder: payable(address(0))
        }));
    }

    function bid(uint256 _auction_item_id) public payable {
        require(
            auction_items[_auction_item_id].start_time <= block.timestamp &&
                auction_items[_auction_item_id].end_time >= block.timestamp,
            "Auction is not active"
        );
       require(
            auction_items[_auction_item_id].highest_bid < msg.value && auction_items[_auction_item_id].min_bid <= msg.value,
            "Bid amount is less than the highest bid"
        );
        if (auction_items[_auction_item_id].highest_bidder != address(0)) {
            auction_items[_auction_item_id].highest_bidder.transfer(
                auction_items[_auction_item_id].highest_bid
            );
        }
        auction_items[_auction_item_id].highest_bid = msg.value;
        auction_items[_auction_item_id].highest_bidder = payable(msg.sender);
    }

    function end_auction_seller(uint256 _auction_item_id) public {
        require(
            artwork_token.ownerOf(auction_items[_auction_item_id].artwork_token_id) ==
                msg.sender,
            "Caller is not the owner of the artwork"
        );
        require(
            auction_items[_auction_item_id].end_time <= block.timestamp,
            "Auction is still active"
        );
        auction_end_handler(_auction_item_id);
   }

    function end_auction_buyer(uint256 _auction_item_id) public {
        require(
            auction_items[_auction_item_id].end_time <= block.timestamp,
            "Auction is still active"
        );
        require(
            auction_items[_auction_item_id].highest_bidder == msg.sender,
            "Caller is not the highest bidder"
        );
        auction_end_handler(_auction_item_id);
   }


    // ------------------ private functions ------------------
    function auction_end_handler(uint256 _auction_item_id) private{
        artwork_token.safeTransferFrom(
            artwork_token.ownerOf(auction_items[_auction_item_id].artwork_token_id),
            auction_items[_auction_item_id].highest_bidder,
            auction_items[_auction_item_id].artwork_token_id
        );
        payable(msg.sender).transfer(auction_items[_auction_item_id].highest_bid);

        for (uint256 i = 0; i < auction_items.length; i++) {
            if (auction_items[i].auction_item_id == _auction_item_id) {
                auction_items[i] = auction_items[auction_items.length - 1];
                auction_items.pop();
                break;
            }
        }
    }
    function add_original_artwork(
        address payable _artist_address,
        string memory _description,
        string memory _img_ipfs_hash
    ) private returns (uint256) {
        OriginalArtwork memory new_artwork = OriginalArtwork({
            is_verified: false,
            original_artwork_id: _original_artwork_id_counter.current(),
            count: 0,
            artist_address: _artist_address,
            description: _description,
            img_ipfs_hash: _img_ipfs_hash
        });
        original_artworks.push(new_artwork);
        _original_artwork_id_counter.increment();
        return new_artwork.original_artwork_id;
    }

    function mint_artwork(
        address _owner,
        uint256 _original_artwork_id,
        uint256 _count,
        uint256 _price
    ) private {
        for (uint256 i = 0; i < _count; i++) {
            uint256 token_id = _artwork_tokenid_counter.current();
            _artwork_tokenid_counter.increment();
            artwork_token.safeMint(_owner, token_id);
            artworks.push( Artwork({
                is_for_sale: true,
                token_id: token_id,
                original_artwork_id: _original_artwork_id,
                price: _price
            }));
           artwork_collections[_owner].push(token_id);
           original_artworks[_original_artwork_id].count++;
        }
    }
}


