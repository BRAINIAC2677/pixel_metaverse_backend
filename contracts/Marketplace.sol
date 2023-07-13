// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./ArtworkToken.sol";

contract Marketplace is AccessControl {
    using Counters for Counters.Counter;

    ArtworkToken artwork_token;
    Counters.Counter private _artwork_tokenid_counter;
    Counters.Counter private _unique_artwork_id_counter;

    constructor(address _artwork_contract) {
        artwork_token = ArtworkToken(_artwork_contract);
    }

    // ------------- roles -----------------
    bytes32 public constant ARTIST_ROLE = keccak256("ARTIST_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // ------------- data structures -------------

    struct Artist {
        address artist_address;
        string name;
        string img_ipfs_hash;
    }

    struct Artwork {
        bool is_verified;
        uint256 unique_artwork_id;
        uint256 price;
        uint256 count;
        address artist_address;
        string description;
        string img_ipfs_hash;
    }

    Artist[] artists;
    Artwork[] unique_artworks;
    mapping(uint256 => uint256) artworks; // maps erc721 token id to a unique artwork id

    address[] verifiers;
    uint256[] verification_requests; // contains unique artwork ids for which verification is requested

    // --------------- events --------------------

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

    function add_artwork(
        uint256 _price,
        uint256 _count,
        string memory _description,
        string memory _img_ipfs_hash
    ) public {
        require(hasRole(ARTIST_ROLE, msg.sender), "Caller is not an artist");
        uint256 unique_artwork_id = add_unique_artwork(
            _price,
            msg.sender,
            _description,
            _img_ipfs_hash
        );
        mint_artwork(msg.sender, unique_artwork_id, _count);
    }

    function increae_artwork_count(
        uint256 _unique_artwork_id,
        uint256 _increase
    ) public {
        require(
            unique_artworks[_unique_artwork_id].artist_address == msg.sender,
            "Caller is not the owner of the artwork"
        );
        mint_artwork(msg.sender, _unique_artwork_id, _increase);
    }

    function request_verification(uint256 _unique_artwork_id) public {
        require(
            unique_artworks[_unique_artwork_id].artist_address == msg.sender,
            "Caller is not the owner of the artwork"
        );
        require(
            !unique_artworks[_unique_artwork_id].is_verified,
            "Artwork is already verified"
        );
        verification_requests.push(_unique_artwork_id);
    }

    function verify_artwork(uint256 _unique_artwork_id) public {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        require(
            !unique_artworks[_unique_artwork_id].is_verified,
            "Artwork is already verified"
        );
        unique_artworks[_unique_artwork_id].is_verified = true;
        for (uint256 i = 0; i < verification_requests.length; i++) {
            if (verification_requests[i] == _unique_artwork_id) {
                verification_requests[i] = verification_requests[
                    verification_requests.length - 1
                ];
                verification_requests.pop();
                break;
            }
        }
    }

    function get_artist_artworks() public view returns (Artwork[] memory) {
        Artwork[] memory artist_artworks = new Artwork[](
            unique_artworks.length
        );
        uint256 count = 0;
        for (uint256 i = 0; i < unique_artworks.length; i++) {
            if (unique_artworks[i].artist_address == msg.sender) {
                artist_artworks[count] = unique_artworks[i];
                count++;
            }
        }
        return artist_artworks;
    }

    function get_verification_requests()
        public
        view
        returns (Artwork[] memory)
    {
        require(hasRole(VERIFIER_ROLE, msg.sender), "Caller is not a verifier");
        Artwork[] memory verification_requests_artworks = new Artwork[](
            verification_requests.length
        );
        for (uint256 i = 0; i < verification_requests.length; i++) {
            verification_requests_artworks[i] = unique_artworks[
                verification_requests[i]
            ];
        }
        return verification_requests_artworks;
    }

    // ------------------ private functions ------------------
    function add_unique_artwork(
        uint256 _price,
        address _artist_address,
        string memory _description,
        string memory _img_ipfs_hash
    ) private returns (uint256) {
        Artwork memory new_artwork = Artwork({
            is_verified: false,
            unique_artwork_id: _unique_artwork_id_counter.current(),
            price: _price,
            count: 0,
            artist_address: _artist_address,
            description: _description,
            img_ipfs_hash: _img_ipfs_hash
        });
        unique_artworks.push(new_artwork);
        _unique_artwork_id_counter.increment();
        return new_artwork.unique_artwork_id;
    }

    function mint_artwork(
        address _owner,
        uint256 _unique_artwork_id,
        uint256 _count
    ) private {
        for (uint256 i = 0; i < _count; i++) {
            uint256 token_id = _artwork_tokenid_counter.current();
            _artwork_tokenid_counter.increment();
            artwork_token.safeMint(_owner, token_id);
            unique_artworks[_unique_artwork_id].count++;
            artworks[token_id] = _unique_artwork_id;
        }
    }
}
