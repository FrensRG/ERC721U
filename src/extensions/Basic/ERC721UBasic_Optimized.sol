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
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant _BITPOS_ADDRESS = 160;

    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    uint256 private constant _BITMASK_START_TIMESTAMP = (1 << 64) - 1;

    uint256 private constant _BITPOS_MINTED_BALANCE = 224;

    uint256 private constant _BITMASK_MINTED_BALANCE = (1 << 16) - 1;

    uint256 private constant _BITMASK_BURNED = 1 << 240;

    uint256 private constant _BITVALUE_MINTED_BALANCE = 1 << 224;

    uint256 private constant _BITMASK_INITIALIZED = 1 << 80;

    uint256 private constant _BITPOS_BALANCE = 64;

    bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /*//////////////////////////////////////////////////////////////
                         METADATA STORAGE/LOGIC
    //////////////////////////////////////////////////////////////*/

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    // Mapping from token ID to ownership details
    // Bits Layout:
    // - [0..159]   `addr`
    // - [160..223] `startTimestamp`
    // - [224..239] `mintedBalance`
    // - [240]      `burned`
    // - [241..255] `extraData`
    mapping(uint256 => uint256) private _packedOwnerOf;

    // Mapping from token ID to balance details
    // Bits Layout:
    // - [0..63]   `balance`
    // - [64..79]  `numberMinted`
    // - [80]      `initialized`
    // - [81..255] `extraData`
    mapping(address => uint256) private _packedBalanceOf;

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
    }

    /*//////////////////////////////////////////////////////////////
                            IERC721 METADATA
    //////////////////////////////////////////////////////////////*/

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

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
                        ADDRESS DATA OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (owner == address(0)) revert OwnerZeroAddress();

        return
            uint64(_packedBalanceOf[owner]) +
            ((_packedOwnerOf[uint160(owner)] >> _BITPOS_MINTED_BALANCE) &
                _BITMASK_MINTED_BALANCE);
    }

    function _numberBurned(address owner) internal view returns (uint256) {
        return
            (_packedBalanceOf[owner] >> _BITPOS_BALANCE) &
            _BITMASK_MINTED_BALANCE;
    }

    function _isBurned(uint256 tokenId) internal view returns (uint256) {
        return _packedOwnerOf[tokenId] & _BITMASK_BURNED;
    }

    function _startTimestamp(uint256 tokenId) internal view returns (uint256) {
        return
            (_packedOwnerOf[tokenId] >> _BITPOS_ADDRESS) &
            _BITMASK_START_TIMESTAMP;
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address owner)
    {
        if (
            (owner = address(uint160(_packedOwnerOf[tokenId]))) == address(0) ||
            _packedOwnerOf[tokenId] & _BITMASK_BURNED != 0
        ) revert OwnerQueryForNonexistentToken();
    }

    function _packOwnershipData(address owner, uint256 extra)
        private
        view
        returns (uint256 result)
    {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // `owner | (block.timestamp << _BITPOS_ADDRESS) | (mintedBalance << _MINTED_BALANCE | burned)`.
            result := or(owner, or(shl(_BITPOS_ADDRESS, timestamp()), extra))
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
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

    /**
     * @dev Returns whether `msgSender` is equal to `approvedAddress` or `owner`.
     */
    function _isSenderApprovedOrOwner(
        address approvedAddress,
        address owner,
        address msgSender
    ) private pure returns (bool result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // Mask `msgSender` to the lower 160 bits, in case the upper bits somehow aren't clean.
            msgSender := and(msgSender, _BITMASK_ADDRESS)
            // `msgSender == owner || msgSender == approvedAddress`.
            result := or(eq(msgSender, owner), eq(msgSender, approvedAddress))
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return
            address(uint160(_packedOwnerOf[tokenId])) != address(0) &&
            _packedOwnerOf[tokenId] & _BITMASK_BURNED == 0;
    }

    function approve(address spender, uint256 tokenId)
        public
        payable
        virtual
        override
    {
        address owner = address(uint160(_packedOwnerOf[tokenId]));
        if (msg.sender != owner)
            if (!isApprovedForAll[owner][msg.sender])
                revert ApprovalCallerNotOwnerNorApproved();

        getApproved[tokenId] = spender;

        emit Approval(owner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        if (from != address(uint160(_packedOwnerOf[tokenId])))
            revert TransferFromIncorrectOwner();

        if (to == address(0)) revert TransferToZeroAddress();

        if (!_isSenderApprovedOrOwner(getApproved[tokenId], from, msg.sender))
            if (!isApprovedForAll[from][msg.sender])
                revert TransferCallerNotOwnerNorApproved();

        if (_packedBalanceOf[to] & _BITMASK_INITIALIZED != 0) {
            unchecked {
                --_packedBalanceOf[from];
                ++_packedBalanceOf[to];
            }
            _packedOwnerOf[tokenId] = _packOwnershipData(to, 0);

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        } else {
            unchecked {
                uint256 balance = uint64(_packedBalanceOf[from]) +
                    ((_packedOwnerOf[tokenId] >> _BITPOS_MINTED_BALANCE) &
                        _BITMASK_MINTED_BALANCE);

                uint256 numberBurned = (_packedBalanceOf[to] >>
                    _BITPOS_BALANCE) & _BITMASK_MINTED_BALANCE;

                _packedBalanceOf[to] =
                    balance |
                    (numberBurned << _BITPOS_BALANCE) |
                    _BITMASK_INITIALIZED;

                _packedOwnerOf[tokenId] = _packOwnershipData(to, 0);
            }

            delete getApproved[tokenId];

            emit Transfer(from, to, tokenId);
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override {
        transferFrom(from, to, tokenId);

        if (to.code.length != 0)
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    ""
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert TransferToNonERC721ReceiverImplementer();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) public payable virtual override {
        transferFrom(from, to, tokenId);

        if (to.code.length != 0)
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert TransferToNonERC721ReceiverImplementer();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to) internal virtual {
        if (to == address(0)) revert MintToZeroAddress();
        uint256 tokenId = uint160(to);
        if (address(uint160(_packedOwnerOf[tokenId])) != address(0))
            revert AddressAlreadyMinted();

        _packedOwnerOf[tokenId] = _packOwnershipData(
            to,
            _BITVALUE_MINTED_BALANCE
        );

        uint256 toMasked;
        assembly {
            // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
            toMasked := and(to, _BITMASK_ADDRESS)
            // Emit the `Transfer` event.
            log4(
                0, // Start of data (0, since no data).
                0, // End of data (0, since no data).
                _TRANSFER_EVENT_SIGNATURE, // Signature.
                0, // `address(0)`.
                toMasked, // `to`.
                tokenId // `tokenId`.
            )
        }
    }

    function _burn(uint256 tokenId) internal virtual {
        uint256 genesisOwner = _packedOwnerOf[tokenId];

        address from = address(uint160(genesisOwner));

        if (genesisOwner & _BITMASK_BURNED != 0)
            revert BurnedQueryForNonexistentToken();

        if (from == address(0)) revert BurnedQueryForNonexistentToken();

        if (_packedBalanceOf[from] & _BITMASK_INITIALIZED != 0) {
            unchecked {
                _packedBalanceOf[from] += (1 << _BITPOS_BALANCE) - 1;
            }

            _packedOwnerOf[tokenId] = _packOwnershipData(from, _BITMASK_BURNED);

            delete getApproved[tokenId];
            emit Transfer(from, address(0), tokenId);
        } else {
            unchecked {
                uint256 balance = uint64(_packedBalanceOf[from]) +
                    ((_packedOwnerOf[tokenId] >> _BITPOS_MINTED_BALANCE) &
                        _BITMASK_MINTED_BALANCE);
                uint256 numberBurned = (_packedBalanceOf[from] >>
                    _BITPOS_BALANCE) & _BITMASK_MINTED_BALANCE;

                _packedOwnerOf[tokenId] = _packOwnershipData(
                    from,
                    _BITMASK_BURNED
                );

                _packedBalanceOf[from] =
                    --balance |
                    (++numberBurned << _BITPOS_BALANCE) |
                    _BITMASK_INITIALIZED;
            }

            delete getApproved[tokenId];
            emit Transfer(from, address(0), tokenId);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MINT LOGIC
    //////////////////////////////////////////////////////////////*/

    function _safeMint(address to) internal virtual {
        _mint(to);

        if (to.code.length != 0)
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    uint160(to),
                    ""
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert TransferToNonERC721ReceiverImplementer();
    }

    function _safeMint(address to, bytes memory data) internal virtual {
        _mint(to);

        if (to.code.length != 0)
            if (
                ERC721TokenReceiver(to).onERC721Received(
                    msg.sender,
                    address(0),
                    uint160(to),
                    data
                ) != ERC721TokenReceiver.onERC721Received.selector
            ) revert TransferToNonERC721ReceiverImplementer();
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
