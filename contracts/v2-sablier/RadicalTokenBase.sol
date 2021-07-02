// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./RadicalManager.sol";

contract RadicalTokenBase is ERC721 {
    RadicalManager public radicalManager;

    constructor(
        RadicalManager _radicalManager,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        radicalManager = _radicalManager;
    }

    modifier onlyRadicalManager() {
        require(msg.sender == address(radicalManager));
        _;
    }

    function setRadicalManager(RadicalManager _radicalManager) external onlyRadicalManager {
        radicalManager = _radicalManager;
    }

    function forceTransfer(address to, uint256 tokenId) public onlyRadicalManager {
        _transfer(ownerOf(tokenId), to, tokenId);
    }

    function _register(uint256 tokenId, uint256 patronageId, uint256 initialPrice) internal {
        radicalManager.register(address(this), tokenId, patronageId, initialPrice);
    }

    function _mintPatronageToken(address to, uint256 patronageRate) internal returns (uint256) {
        return radicalManager.mintNewPatronageToken(to, patronageRate);
    }
}
