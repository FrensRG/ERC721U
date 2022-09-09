// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {DSTestPlus} from "./DSTestPlus.sol";
import {DSInvariantTest} from "./DSInvariantTest.sol";

import {MockERC721} from "./Mocks/MockERC721.sol";

import {ERC721TokenReceiver} from "../src/ERC721U.sol";

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(
            string(
                abi.encodePacked(ERC721TokenReceiver.onERC721Received.selector)
            )
        );
    }
}

contract WrongReturnDataERC721Recipient is ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721Test is DSTestPlus {
    MockERC721 token;

    function setUp() public {
        token = new MockERC721("Token", "TKN");
    }

    function invariantMetadata() public {
        assertEq(token.name(), "Token");
        assertEq(token.symbol(), "TKN");
    }

    function testMint() public {
        token.mint(address(0xBEEF));

        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.ownerOf(uint160(address(0xBEEF))), address(0xBEEF));
    }

    function testMintAndTransfer() public {
        token.mint(address(0xBEEF));
        token.mint(address(0xCAFE));
        hevm.prank(address(0xBEEF));
        token.transferFrom(
            address(0xBEEF),
            address(0xCAFE),
            uint160(address(0xBEEF))
        );
        assertEq(token.balanceOf(address(0xCAFE)), 2);
        assertEq(token.ownerOf(uint160(address(0xBEEF))), address(0xCAFE));
    }

    function testMintAndTransferGenesis() public {
        token.mint(address(0xBEEF));
        token.mint(address(0xCAFE));
        hevm.prank(address(0xBEEF));
        token.transferFrom(
            address(0xBEEF),
            address(0xCAFE),
            uint160(address(0xBEEF))
        );
        assertEq(token.balanceOf(address(0xCAFE)), 2);
        assertEq(token.ownerOf(uint160(address(0xBEEF))), address(0xCAFE));
        hevm.startPrank(address(0xCAFE));
        token.transferFrom(
            address(0xCAFE),
            address(0xBEEF),
            uint160(address(0xCAFE))
        );
        token.transferFrom(
            address(0xCAFE),
            address(0xBEEF),
            uint160(address(0xBEEF))
        );
        hevm.stopPrank();

        assertEq(token.balanceOf(address(0xCAFE)), 0);
    }

    function testBurn() public {
        token.mint(address(0xBEEF));
        token.burn(uint160(address(0xBEEF)));

        assertEq(token.balanceOf(address(0xBEEF)), 0);
    }

    function testNumberBurned() public {
        token.mint(address(0xBEEF));
        token.burn(uint160(address(0xBEEF)));

        assertEq(token.numberBurned(address(0xBEEF)), 1);
    }

    function testTokenBurned() public {
        token.mint(address(0xBEEF));
        token.burn(uint160(address(0xBEEF)));

        assertTrue(token.isBurned(uint160(address(0xBEEF))));
    }

    function testApprove() public {
        token.mint(address(this));

        token.approve(address(0xBEEF), uint160(address(this)));

        assertEq(token.getApproved(uint160(address(this))), address(0xBEEF));
    }

    function testApproveBurn() public {
        token.mint(address(this));

        token.approve(address(0xBEEF), uint160(address(this)));

        token.burn(uint160(address(this)));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(uint160(address(this))), address(0));
    }

    function testApproveAll() public {
        token.setApprovalForAll(address(0xBEEF), true);

        assertTrue(token.isApprovedForAll(address(this), address(0xBEEF)));
    }

    function testTransferFrom() public {
        address from = address(0xABCD);

        token.mint(from);

        hevm.prank(from);
        token.approve(address(this), uint160(address(0xABCD)));

        token.transferFrom(from, address(0xBEEF), uint160(address(0xABCD)));

        assertEq(token.getApproved(uint160(address(0xABCD))), address(0));
        assertEq(token.ownerOf(uint160(address(0xABCD))), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf() public {
        token.mint(address(this));

        token.transferFrom(
            address(this),
            address(0xBEEF),
            uint160(address(this))
        );

        assertEq(token.getApproved(uint160(address(this))), address(0));
        assertEq(token.ownerOf(uint160(address(this))), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll() public {
        address from = address(0xABCD);

        token.mint(from);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, address(0xBEEF), uint160(address(from)));

        assertEq(token.getApproved(uint160(address(from))), address(0));
        assertEq(token.ownerOf(uint160(address(from))), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA() public {
        address from = address(0xABCD);

        token.mint(from);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(0xBEEF), uint160(address(from)));

        assertEq(token.getApproved(uint160(address(from))), address(0));
        assertEq(token.ownerOf(uint160(address(from))), address(0xBEEF));
        assertEq(token.balanceOf(address(0xBEEF)), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(
            from,
            address(recipient),
            uint160(address(from))
        );

        assertEq(token.getApproved(uint160(address(from))), address(0));
        assertEq(token.ownerOf(uint160(address(from))), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), uint160(address(from)));
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData() public {
        address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from);

        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(
            from,
            address(recipient),
            uint160(address(from)),
            "testing 123"
        );

        assertEq(token.getApproved(uint160(address(from))), address(0));
        assertEq(token.ownerOf(uint160(address(from))), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), uint160(address(from)));
        assertBytesEq(recipient.data(), "testing 123");
    }

    function testSafeMintToEOA() public {
        token.safeMint(address(0xBEEF));

        assertEq(
            token.ownerOf(uint160(address(0xBEEF))),
            address(address(0xBEEF))
        );
        assertEq(token.balanceOf(address(address(0xBEEF))), 1);
    }

    function testSafeMintToERC721RecipientWithData() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), "testing 123");

        assertEq(token.ownerOf(uint160(address(to))), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), uint160(address(to)));
        assertBytesEq(to.data(), "testing 123");
    }

    function testFailDoubleMint() public {
        token.mint(address(0xBEEF));
        token.mint(address(0xBEEF));
    }

    function testFailBurnUnMinted() public {
        token.burn(uint160(address(this)));
    }

    function testFailDoubleBurn() public {
        token.mint(address(0xBEEF));

        token.burn(uint160(address(0xBEEF)));
        token.burn(uint160(address(0xBEEF)));
    }

    function testFailApproveUnMinted() public {
        token.approve(address(0xBEEF), uint160(address(0xBEEF)));
    }

    function testFailApproveUnAuthorized() public {
        token.mint(address(0xCAFE));

        token.approve(address(0xBEEF), uint160(address(0xCAFE)));
    }

    function testFailTransferFromUnOwned() public {
        token.transferFrom(
            address(0xFEED),
            address(0xBEEF),
            uint160(address(0xFEED))
        );
    }

    function testFailTransferFromWrongFrom() public {
        token.mint(address(0xCAFE));

        token.transferFrom(
            address(0xFEED),
            address(0xBEEF),
            uint160(address(0xCAFE))
        );
    }

    function testFailTransferFromNotOwner() public {
        token.mint(address(0xFEED));

        token.transferFrom(
            address(0xFEED),
            address(0xBEEF),
            uint160(address(0xFEED))
        );
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData() public {
        token.mint(address(this));

        token.safeTransferFrom(
            address(this),
            address(new NonERC721Recipient()),
            uint160(address(this)),
            "testing 123"
        );
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData()
        public
    {
        token.mint(address(this));

        token.safeTransferFrom(
            address(this),
            address(new RevertingERC721Recipient()),
            uint160(address(this)),
            "testing 123"
        );
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData()
        public
    {
        token.mint(address(this));

        token.safeTransferFrom(
            address(this),
            address(new WrongReturnDataERC721Recipient()),
            uint160(address(this)),
            "testing 123"
        );
    }

    function testFailSafeMintToNonERC721RecipientWithData() public {
        token.safeMint(address(new NonERC721Recipient()), "testing 123");
    }

    function testFailSafeMintToRevertingERC721RecipientWithData() public {
        token.safeMint(address(new RevertingERC721Recipient()), "testing 123");
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnDataWithData()
        public
    {
        token.safeMint(
            address(new WrongReturnDataERC721Recipient()),
            "testing 123"
        );
    }

    function testFailBalanceOfZeroAddress() public view {
        token.balanceOf(address(0));
    }

    function testFailOwnerOfUnminted() public view {
        token.ownerOf(uint160(address(this)));
    }

    function testMetadata(string memory name, string memory symbol) public {
        MockERC721 tkn = new MockERC721(name, symbol);

        assertEq(tkn.name(), name);
        assertEq(tkn.symbol(), symbol);
    }

    function testMint(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to);

        assertEq(token.balanceOf(to), 1);
        assertEq(token.ownerOf(uint160(address(to))), to);
    }

    function testBurn(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to);
        token.burn(uint160(address(to)));

        assertEq(token.balanceOf(to), 0);
    }

    function testApprove(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(address(this));

        token.approve(to, uint160(address(this)));

        assertEq(token.getApproved(uint160(address(this))), to);
    }

    function testApproveBurn(address to) public {
        token.mint(address(this));

        token.approve(address(to), uint160(address(this)));

        token.burn(uint160(address(this)));

        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.getApproved(uint160(address(to))), address(0));
    }

    function testApproveAll(address to, bool approved) public {
        token.setApprovalForAll(to, approved);

        assertBoolEq(token.isApprovedForAll(address(this), to), approved);
    }

    function testTransferFrom(address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from);

        hevm.prank(from);
        token.approve(address(this), uint160(address(from)));

        token.transferFrom(from, to, uint160(address(from)));

        assertEq(token.getApproved(uint160(address(from))), address(0));
        assertEq(token.ownerOf(uint160(address(from))), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testTransferFromSelf(address to) public {
        if (to == address(0) || to == address(this)) to = address(0xBEEF);

        token.mint(address(this));
        uint256 id = uint160(address(this));

        token.transferFrom(address(this), to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function testTransferFromApproveAll(address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        token.mint(from);
        uint256 id = uint160(address(from));
        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.transferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToEOA(address to) public {
        address from = address(0xABCD);

        if (to == address(0) || to == from) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.mint(from);
        uint256 id = uint160(address(from));
        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, to, id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.balanceOf(from), 0);
    }

    function testSafeTransferFromToERC721Recipient(address from) public {
        //address from = address(0xABCD);
        ERC721Recipient recipient = new ERC721Recipient();
        if (
            from == address(0) ||
            from == address(this) ||
            from == address(recipient)
        ) from = address(0xBEEF);

        token.mint(from);
        uint256 id = uint256(uint160(address(from)));
        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), "");
    }

    function testSafeTransferFromToERC721RecipientWithData(
        address from,
        bytes calldata data
    ) public {
        //address from = address(0xABCD);
        if (from == address(0) || from == address(this)) from = address(0xBEEF);
        ERC721Recipient recipient = new ERC721Recipient();

        token.mint(from);
        uint256 id = uint160(address(from));
        hevm.prank(from);
        token.setApprovalForAll(address(this), true);

        token.safeTransferFrom(from, address(recipient), id, data);

        assertEq(token.getApproved(id), address(0));
        assertEq(token.ownerOf(id), address(recipient));
        assertEq(token.balanceOf(address(recipient)), 1);
        assertEq(token.balanceOf(from), 0);

        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), from);
        assertEq(recipient.id(), id);
        assertBytesEq(recipient.data(), data);
    }

    function testSafeMintToEOA(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        if (uint256(uint160(to)) <= 18 || to.code.length > 0) return;

        token.safeMint(to);
        uint256 id = uint160(address(to));
        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);
    }

    function testSafeMintToERC721Recipient() public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to));
        uint256 id = uint160(address(to));
        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), "");
    }

    function testSafeMintToERC721RecipientWithData(bytes calldata data) public {
        ERC721Recipient to = new ERC721Recipient();

        token.safeMint(address(to), data);
        uint256 id = uint160(address(to));
        assertEq(token.ownerOf(id), address(to));
        assertEq(token.balanceOf(address(to)), 1);

        assertEq(to.operator(), address(this));
        assertEq(to.from(), address(0));
        assertEq(to.id(), id);
        assertBytesEq(to.data(), data);
    }

    function testFailMintToZero() public {
        token.mint(address(0));
    }

    function testFailDoubleMint(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to);
        token.mint(to);
    }

    function testFailBurnUnMinted(uint256 id) public {
        token.burn(id);
    }

    function testFailDoubleBurn(address to) public {
        if (to == address(0)) to = address(0xBEEF);

        token.mint(to);
        uint256 id = uint160(address(to));
        token.burn(id);
        token.burn(id);
    }

    function testFailApproveUnMinted(address to) public {
        uint256 id = uint160(address(to));
        token.approve(to, id);
    }

    function testFailApproveUnAuthorized(address owner, address to) public {
        if (owner == address(0) || owner == address(this))
            owner = address(0xBEEF);

        uint256 id = uint160(address(owner));
        token.mint(owner);

        token.approve(to, id);
    }

    function testFailTransferFromUnOwned(address from, address to) public {
        uint256 id = uint160(address(from));
        token.transferFrom(from, to, id);
    }

    function testFailTransferFromWrongFrom(
        address owner,
        address from,
        address to
    ) public {
        if (owner == address(0)) to = address(0xBEEF);
        if (from == owner) revert();

        token.mint(owner);
        uint256 id = uint160(address(owner));
        token.transferFrom(from, to, id);
    }

    function testFailTransferFromToZero() public {
        token.mint(address(this));

        token.transferFrom(address(this), address(0), uint160(address(this)));
    }

    function testFailTransferFromNotOwner(address from, address to) public {
        if (from == address(this)) from = address(0xBEEF);

        token.mint(from);
        uint256 id = uint160(address(from));
        token.transferFrom(from, to, id);
    }

    function testFailSafeTransferFromToNonERC721Recipient() public {
        token.mint(address(this));
        uint256 id = uint160(address(this));

        token.safeTransferFrom(
            address(this),
            address(new NonERC721Recipient()),
            id
        );
    }

    function testFailSafeTransferFromToNonERC721RecipientWithData(
        bytes calldata data
    ) public {
        token.mint(address(this));
        uint256 id = uint160(address(this));
        token.safeTransferFrom(
            address(this),
            address(new NonERC721Recipient()),
            id,
            data
        );
    }

    function testFailSafeTransferFromToRevertingERC721Recipient() public {
        token.mint(address(this));
        uint256 id = uint160(address(this));
        token.safeTransferFrom(
            address(this),
            address(new RevertingERC721Recipient()),
            id
        );
    }

    function testFailSafeTransferFromToRevertingERC721RecipientWithData(
        bytes calldata data
    ) public {
        token.mint(address(this));
        uint256 id = uint160(address(this));
        token.safeTransferFrom(
            address(this),
            address(new RevertingERC721Recipient()),
            id,
            data
        );
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnData()
        public
    {
        token.mint(address(this));
        uint256 id = uint160(address(this));
        token.safeTransferFrom(
            address(this),
            address(new WrongReturnDataERC721Recipient()),
            id
        );
    }

    function testFailSafeTransferFromToERC721RecipientWithWrongReturnDataWithData(
        bytes calldata data
    ) public {
        token.mint(address(this));
        uint256 id = uint160(address(this));
        token.safeTransferFrom(
            address(this),
            address(new WrongReturnDataERC721Recipient()),
            id,
            data
        );
    }

    function testFailSafeMintToNonERC721Recipient() public {
        token.safeMint(address(new NonERC721Recipient()));
    }

    function testFailSafeMintToNonERC721RecipientWithData(bytes calldata data)
        public
    {
        token.safeMint(address(new NonERC721Recipient()), data);
    }

    function testFailSafeMintToRevertingERC721Recipient() public {
        token.safeMint(address(new RevertingERC721Recipient()));
    }

    function testFailSafeMintToRevertingERC721RecipientWithData(
        bytes calldata data
    ) public {
        token.safeMint(address(new RevertingERC721Recipient()), data);
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnData() public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()));
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnDataWithData(
        bytes calldata data
    ) public {
        token.safeMint(address(new WrongReturnDataERC721Recipient()), data);
    }

    function testFailOwnerOfUnminted(address id) public view {
        token.ownerOf(uint160(address(id)));
    }
}
