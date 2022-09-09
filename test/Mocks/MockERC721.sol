// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721U} from "../../src/ERC721U.sol";

contract MockERC721 is ERC721U {
    constructor(string memory _name, string memory _symbol)
        ERC721U(_name, _symbol)
    {}

    function mint(address to) public virtual {
        _mint(to);
    }

    function burn(uint256 tokenId) public virtual {
        _burn(tokenId);
    }

    function safeMint(address to) public virtual {
        _safeMint(to);
    }

    function safeMint(address to, bytes memory data) public virtual {
        _safeMint(to, data);
    }

    function numberBurned(address owner) public view virtual returns (uint256) {
        return _numberBurned(owner);
    }

    function isBurned(uint256 tokenId) public view virtual returns (bool) {
        return _isBurned(tokenId);
    }
}
