// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./RadicalManager.sol";
import "./RadicalTokenBase.sol";

contract RadicalTokenExample is RadicalTokenBase {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(RadicalManager _radicalManager, string memory _name, string memory _symbol) RadicalTokenBase(_radicalManager, _name, _symbol) {
    }

    function mint(address to, string memory tokenURI, uint256 patronageRate, uint256 initialPrice) public {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _mint(to, tokenId);
        // _setTokenURI(tokenId, tokenURI);

        uint256 patronageId = _mintPatronageToken(to, patronageRate);
        _register(tokenId, patronageId, initialPrice);
    }
}
