// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../BRC2100.sol";
import "../BRC2100Mirror.sol";

contract SimpleBRC2100 is BRC2100{
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 unit_
    ) BRC2100(name_, symbol_){
        address mirror = address(new BRC2100Mirror(name_, symbol_));
        _initializeBRC2100(unit_, mirror);
    }

    function mintFT(uint256 value) public {
        _mintFT(msg.sender, value);
    }

    function mintNFT(uint256 amount) public {
        _mintNFT(msg.sender, amount);
    }

    function convertToFT(uint256 tokenId) public {
        _convertToFT(msg.sender, tokenId);
    }

    function convertToNFT(uint256 value) public {
        _convertToNFT(msg.sender, value);
    }
 }