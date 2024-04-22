// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import  "./IBRC2100.sol";

abstract contract BRC2100 is IBRC2100 {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    string private _name;
    string private _symbol; 

    uint256 private _totalSupply;

    uint256 private _unit;
    address private _mirror;

    bool private initialized;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function _initializeBRC2100(uint256 unit_, address mirror_) internal virtual {
        require(!initialized, "already initialized");
        initialized = true;

        _unit = unit_;
        _mirror = mirror_;

        (bool success, ) = _mirror.call(abi.encodeWithSignature("initializeBRC2100Mirror(address)", address(this)));
        require(success);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }
    
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }
    
    function mirror() public view virtual returns (address) {
        return _mirror;
    }

    function unit() public view virtual returns (uint256) {
        return _unit;
    }

    function _mirrorMint(address owner) internal virtual {
        require(msg.sender == _mirror);
        _mintFT(owner, _unit);
    }

    function _convertToFT(address owner, uint256 tokenId) internal virtual {
        (bool success, ) = _mirror.call(abi.encodeWithSignature("convertToFT(address,uint256)", owner, tokenId));
        require(success);
    }

    function _convertToNFT(address owner, uint256 value) internal virtual {
        require(value >= _unit);
        uint256 nftAmount = value / _unit;
        uint256 ftAmount = nftAmount * _unit;
        _burn(owner, ftAmount);
        _mintNFT(owner, nftAmount);
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "invalid sender");
        require(to != address(0), "invalid receiver");
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            require(fromBalance >= value, "insufficient balance");
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mintFT(address account, uint256 value) internal {
        require(account != address(0), "invalid receiver");
        _update(address(0), account, value);
    }

    function _mintNFT(address account, uint256 amount) internal {
        (bool success, ) = _mirror.call(abi.encodeWithSignature("sourceMint(address,uint256)", account, amount));
        require(success);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), "invalid sender");
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        require(owner != address(0), "invalid approver");
        require(spender != address(0), "invalid spender");
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    modifier brc2100Fallback() virtual {
        uint256 fnSelector = _calldataload(0x00) >> 224;
        // `mirrorMint(address)`.
        if (fnSelector == 0x92e7ddcb) {
            require(msg.sender == _mirror);
            _mirrorMint(address(uint160(_calldataload(0x04))));
            _return(1);
        }
        _;
    }

    fallback() external payable virtual brc2100Fallback {
        revert();
    }
    
    receive() external payable virtual {
        revert();
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