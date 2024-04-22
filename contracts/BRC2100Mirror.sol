// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import  "./IBRC2100Mirror.sol";

contract BRC2100Mirror is IBRC2100Mirror {
    string private _name;
    string private _symbol;
    address private _source;
    uint256 private _nextTokenId = _startTokenId();

    uint256[] private burnedTokenIds;

    mapping(uint256 tokenId => address) private _owners;
    mapping(address owner => uint256) private _balances;
    mapping(uint256 tokenId => address) private _tokenApprovals;
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;
    

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function _initializeBRC2100Mirror(
        address source_
    ) internal virtual {
        require(source_ != address(0));
        require(_source == address(0));
        _source = source_;
    }

    function _sourceMint(address owner, uint256 amount) internal virtual {
        require(msg.sender == _source);
        uint256 mintAmount = burnedTokenIds.length >= amount ? 0 : amount - burnedTokenIds.length;
        uint256 restoreAmount = amount - mintAmount;
        for (uint256 i = 0; i < mintAmount; i ++) {
            _mint(owner);
        }
        for (uint256 i = 0; i < restoreAmount; i ++) {
            uint256 tokenId = burnedTokenIds[burnedTokenIds.length - 1];
            burnedTokenIds.pop();
            _restoreBurnedToken(owner,tokenId);
        }
    }

    function _convertToFT(address owner, uint256 tokenId) internal virtual {
        _burn(tokenId);
        (bool success, ) = _source.call(abi.encodeWithSignature("mirrorMint(address)", owner));
        require(success);
    }

    function _startTokenId() internal pure virtual returns(uint256) {
        return 1;
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "invalid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function source() public view virtual returns (address) {
        return _source;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _nextTokenId - _startTokenId() - burnedTokenIds.length;
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, _toString(tokenId)) : "";
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, msg.sender);
    }

    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        require(to != address(0), "invalid receiver");
        address previousOwner = _update(to, tokenId, msg.sender);
        require(previousOwner == from, "incorrect owner");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    }

    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        require(_isAuthorized(owner, spender, tokenId));
    }

    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    function _mint(address to) internal {
        require(to != address(0), "invalid receiver");
        address previousOwner = _update(to, _nextTokenId, address(0));
        _nextTokenId ++;
        require(previousOwner == address(0), "invalid sender");
    }

    function _restoreBurnedToken(address to, uint256 tokenId) private {
        require(to != address(0), "invalid receiver");
        address previousOwner = _update(to, tokenId, address(0));
        require(previousOwner == address(0), "invalid sender");
    }

    function _safeMint(address to) internal {
        _safeMint(to, "");
    }

    function _safeMint(address to, bytes memory data) internal virtual {
        _checkOnERC721Received(address(0), to, _nextTokenId, data);
        _mint(to);
    }

    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        require(previousOwner != address(0), "nonexistent token");
        burnedTokenIds.push(tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(to != address(0), "invalid receiver");
        address previousOwner = _update(to, tokenId, address(0));
        require(previousOwner != address(0) && previousOwner != from);
    }

    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert("invalid approver");
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(operator != address(0), "invalid operator");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "nonexist token");
        return owner;
    }

    function _checkOnERC721Received(address from, address to, uint256 id, bytes memory data)
        private
    {
        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the calldata.
            let m := mload(0x40)
            let onERC721ReceivedSelector := 0x150b7a02
            mstore(m, onERC721ReceivedSelector)
            mstore(add(m, 0x20), caller()) // The `operator`, which is always `msg.sender`.
            mstore(add(m, 0x40), shr(96, shl(96, from)))
            mstore(add(m, 0x60), id)
            mstore(add(m, 0x80), 0x80)
            let n := mload(data)
            mstore(add(m, 0xa0), n)
            if n { pop(staticcall(gas(), 4, add(data, 0x20), n, add(m, 0xc0), n)) }
            // Revert if the call reverts.
            if iszero(call(gas(), to, 0, add(m, 0x1c), add(n, 0xa4), m, 0x20)) {
                if returndatasize() {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(m, 0x00, returndatasize())
                    revert(m, returndatasize())
                }
            }
            // Load the returndata and compare it.
            if iszero(eq(mload(m), shl(224, onERC721ReceivedSelector))) {
                mstore(0x00, 0xd1a57ed6) // `TransferToNonERC721ReceiverImplementer()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = _log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), "0123456789abcdef"))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function _log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    modifier brc2100MirrorFallback() virtual {
        uint256 fnSelector = _calldataload(0x00) >> 224;
        // `sourceMint(address,uint256)`.
        if (fnSelector == 0x1b03fbcb) {
            _initializeBRC2100Mirror(address(uint160(_calldataload(0x04))));
            _return(1);
        // `initializeBRC2100Mirror(address)`
        } else if (fnSelector == 0x66bd3d45) {
            require(msg.sender == _source);
            _sourceMint(address(uint160(_calldataload(0x04))), _calldataload(0x24));
            _return(1);
        // `convertToFT(address,uint256)`
        } else if (fnSelector == 0x46420916) {
            require(msg.sender == _source);
            _convertToFT(address(uint160(_calldataload(0x04))), _calldataload(0x24));
            _return(1);
        }
        _;
    }

    fallback() external payable virtual brc2100MirrorFallback {
        revert();
    }
    
    receive() external payable virtual {
        if (msg.value != 0) revert();
    }

    /// @dev Returns the calldata value at `offset`.
    function _calldataload(uint256 offset) private pure returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := calldataload(offset)
        }
    }

    /// @dev Executes a return opcode to return `x` and end the current call frame.
    function _return(uint256 x) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, x)
            return(0x00, 0x20)
        }
    }
}