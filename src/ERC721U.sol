// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC721U.sol";

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

contract ERC721U is IERC721U {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Struct used in ownerOf mapping to keep track of ownership and minted balance
     * This way we can do just one SSTORE to save gas on mint
     */
    struct GenesisOwner {
        //Token owner
        address owner;
        //when the ownership started
        uint64 startTimestamp;
        //Balance after minting which will always be 1
        uint16 mintedBalance;
        //If the token is burned
        bool burned;
    }

    /**
     * @dev Struct used in balanceOf mapping to keep track of ownership and minted balance
     * This way we can do just one SSTORE to save gas on mint
     */
    struct GenesisBalance {
        //Number of owned tokens. This will update  on first transfer to another EOA or ERC721Receiver
        uint64 balance;
        //Number of tokens burned
        uint16 numberBurned;
        //If the mapping is initialized
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

    // Mapping from token ID to ownership details
    mapping(uint256 => GenesisOwner) private _ownerOf;

    // Mapping owner address to balance data
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
        _currentIndex = _startCounter();
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
                ? string(abi.encodePacked(baseURI, toString(tokenId)))
                : "";
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN COUNTING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Start counter to keep track of total supply and minted supply.
     * Starts at 1 because it saves gas for first minter
     * Override this method if you which to change this behavior
     */
    function _startCounter() internal view virtual returns (uint256) {
        return 1;
    }

    function totalSupply() public view virtual returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than `_currentIndex - _startTokenId()` times.
        unchecked {
            return _currentIndex - _burnCounter - _startCounter();
        }
    }

    function _totalMinted() internal view virtual returns (uint256) {
        // Counter underflow is impossible as `_currentIndex` does not decrement,
        // and it is initialized to `_startTokenId()`.
        unchecked {
            return _currentIndex - _startCounter();
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
        //Overflow is incredibly unrealistic
        unchecked {
            //Adds both values to reveal real balance in cases the genesis minter still has the token but acquired more tokens.
            return
                _balanceOf[owner].balance +
                _ownerOf[uint160(owner)].mintedBalance;
        }
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

    /**
     * @dev Checks ownership of the tokendId provided
     * Token cannot be burned or owned by address 0
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        returns (address owner)
    {
        require(
            (owner = _ownerOf[tokenId].owner) != address(0) &&
                !_ownerOf[tokenId].burned,
            "NOT_EXISTANT_TOKEN"
        );
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

    function approve(address spender, uint256 id) public payable virtual {
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
    ) public payable virtual {
        require(from == _ownerOf[tokenId].owner, "WRONG_FROM");

        require(to != address(0), "INVALID_RECIPIENT");

        require(
            msg.sender == from ||
                isApprovedForAll[from][msg.sender] ||
                msg.sender == getApproved[tokenId],
            "NOT_AUTHORIZED"
        );
        //Check if the balance mapping has been initialized.
        if (_balanceOf[to].initialized) {
            //Updates the mapping and updates the owner.
            unchecked {
                --_balanceOf[from].balance;
                ++_balanceOf[to].balance;
            }

            _ownerOf[tokenId].owner = to;
            _ownerOf[tokenId].startTimestamp = uint64(block.timestamp);

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        } else {
            // Means the person transfering is one of the genesis minters.
            //Initializes the mapping and cleans the minted balance and updates the owner.
            GenesisBalance memory genesisBalance = _balanceOf[to];
            unchecked {
                _balanceOf[to] = GenesisBalance(
                    genesisBalance.balance + _ownerOf[tokenId].mintedBalance,
                    genesisBalance.numberBurned,
                    true
                );

                _ownerOf[tokenId].owner = to;
                _ownerOf[tokenId].startTimestamp = uint64(block.timestamp);
                _ownerOf[tokenId].mintedBalance = 0;
            }

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual {
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
    ) public payable virtual {
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
        // No need to initialized the burned false since the default is false.
        unchecked {
            _ownerOf[tokenId].owner = to;
            _ownerOf[tokenId].startTimestamp = uint64(block.timestamp);
            _ownerOf[tokenId].mintedBalance = 1;

            ++_currentIndex;
        }

        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        GenesisOwner memory genesisOwner = _ownerOf[tokenId];

        require(!genesisOwner.burned, "BURNED");
        require(genesisOwner.owner != address(0), "NOT_MINTED");

        if (_balanceOf[genesisOwner.owner].initialized) {
            unchecked {
                --_balanceOf[genesisOwner.owner].balance;
                ++_balanceOf[genesisOwner.owner].numberBurned;
            }

            _ownerOf[tokenId].startTimestamp = uint64(block.timestamp);
            _ownerOf[tokenId].burned = true;

            delete getApproved[tokenId];
            emit Transfer(genesisOwner.owner, address(0), tokenId);
        } else {
            // Means the person burning is one of the genesis minters.
            // Initializes the mapping and cleans the minted balance and updates the token to a burned one.
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

    /*//////////////////////////////////////////////////////////////
                              OTHER LOGIC
    //////////////////////////////////////////////////////////////*/

    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit),
            // but we allocate 0x80 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 32-byte word to store the length,
            // and 3 32-byte words to store a maximum of 78 digits. Total: 0x20 + 3 * 0x20 = 0x80.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, str)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}
