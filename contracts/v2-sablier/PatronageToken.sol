// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PatronageToken is ERC721, Ownable {
    constructor() ERC721("Radical Finance Patronage Token", "PATRONAGE") {
        // TODO: Something?
    }

    mapping(uint256 => uint256) _patronageRates;

    function rateOf(uint256 tokenId) public view returns (uint256) {
        return _patronageRates[tokenId];
    }

    function mint(address to, uint256 tokenId, uint256 patronageRate) public onlyOwner {
        _patronageRates[tokenId] = patronageRate;
        _mint(to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        // Change sablier receiver on radical manager
    }
}
