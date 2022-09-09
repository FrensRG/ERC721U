// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC721U.sol";
import {LibStringUtils} from "lib/LibStringUtils/src/LibStringUtils.sol";

abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract ERC721U {
    using LibStringUtils for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct GenesisOwner {
        address owner;
        uint64 startTimestamp;
        uint16 mintedBalance;
        bool hasMinted;
        bool burned;
    }

    struct GenesisBalance {
        uint64 balance;
        uint16 numberBurned;
        bool initialized;
    }

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    // The next token ID to be minted.
    uint256 private _currentIndex;

    // The number of tokens burned.
    uint256 private _burnCounter;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => GenesisOwner) private _ownerOf;

    mapping(address => GenesisBalance) private _balanceOf;

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public getApproved;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    /*//////////////////////////////////////////////////////////////
                            IERC721 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        returns (string memory)
    {
        require(_exists(tokenId), "NON_EXISTENT_TOKEN");

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN COUNTING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function _startTokenId() internal view virtual returns (uint256) {
        return 1;
    }

    function totalSupply() public view virtual returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than `_currentIndex - _startTokenId()` times.
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    function _totalMinted() internal view virtual returns (uint256) {
        // Counter underflow is impossible as `_currentIndex` does not decrement,
        // and it is initialized to `_startTokenId()`.
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    function _totalBurned() internal view virtual returns (uint256) {
        return _burnCounter;
    }

    /*//////////////////////////////////////////////////////////////
                        ADDRESS DATA OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");
        return
            _balanceOf[owner].balance + _ownerOf[uint160(owner)].mintedBalance;
    }

    function _hasMinted(address owner) internal view virtual returns (bool) {
        return _ownerOf[uint160(owner)].hasMinted;
    }

    function _numberBurned(address owner) internal view returns (uint256) {
        return _balanceOf[owner].numberBurned;
    }

    function _isBurned(uint256 tokenId) internal view returns (bool) {
        return _ownerOf[tokenId].burned;
    }

    function _startTimestamp(uint256 tokenId) internal view returns (uint256) {
        return _ownerOf[tokenId].startTimestamp;
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        returns (address owner)
    {
        require((owner = _ownerOf[tokenId].owner) != address(0), "NOT_MINTED");
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f; // ERC165 interface ID for ERC721Metadata.
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return
            _ownerOf[tokenId].owner != address(0) && // If within bounds,
            !_ownerOf[tokenId].burned; // and not burned.
    }

    function approve(address spender, uint256 id) public virtual {
        address owner = _ownerOf[id].owner;

        require(
            msg.sender == owner || isApprovedForAll[owner][msg.sender],
            "NOT_AUTHORIZED"
        );

        getApproved[id] = spender;

        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        require(from == _ownerOf[tokenId].owner, "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from ||
                isApprovedForAll[from][msg.sender] ||
                msg.sender == getApproved[tokenId],
            "NOT_AUTHORIZED"
        );

        if (_balanceOf[to].initialized) {
            unchecked {
                --_balanceOf[from].balance;
                ++_balanceOf[to].balance;
            }

            _ownerOf[tokenId].owner = to;

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        } else {
            GenesisBalance memory genesisBalance = _balanceOf[to];
            unchecked {
                _balanceOf[to] = GenesisBalance(
                    genesisBalance.balance + _ownerOf[tokenId].mintedBalance,
                    genesisBalance.numberBurned,
                    true
                );

                _ownerOf[tokenId] = GenesisOwner(
                    to,
                    uint64(block.timestamp),
                    0,
                    true,
                    false
                );
            }

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        transferFrom(from, to, tokenId);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    ""
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, tokenId);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");
        uint256 tokenId = uint160(to);

        require(_ownerOf[tokenId].owner == address(0), "ALREADY_MINTED");

        // Counter overflow is incredibly unrealistic.
        unchecked {
            _ownerOf[tokenId] = GenesisOwner(
                to,
                uint64(block.timestamp),
                1,
                true,
                false
            );

            ++_currentIndex;
        }

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        GenesisOwner memory genesisOwner = _ownerOf[tokenId];

        require(!genesisOwner.burned, "ALREADY_BURNED");
        require(genesisOwner.owner != address(0), "NOT_MINTED");

        if (_balanceOf[genesisOwner.owner].initialized) {
            unchecked {
                --_balanceOf[genesisOwner.owner].balance;
                ++_balanceOf[genesisOwner.owner].numberBurned;
            }

            _ownerOf[tokenId] = GenesisOwner(
                address(0),
                uint64(block.timestamp),
                0,
                true,
                true
            );
            delete getApproved[tokenId];
            emit Transfer(genesisOwner.owner, address(0), tokenId);
        } else {
            unchecked {
                --_ownerOf[tokenId].mintedBalance;
                ++_balanceOf[genesisOwner.owner].numberBurned;
            }
            _ownerOf[tokenId].burned = true;

            delete getApproved[tokenId];
            emit Transfer(genesisOwner.owner, address(0), tokenId);
        }

        unchecked {
            ++_burnCounter;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to) internal virtual {
        _mint(to);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    uint160(to),
                    ""
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(address to, bytes memory data) internal virtual {
        _mint(to);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    uint160(to),
                    data
                ) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}
