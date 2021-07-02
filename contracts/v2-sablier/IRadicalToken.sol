// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { RadicalManager } from "./RadicalManager.sol";

interface IRadicalToken is IERC721 {
    function radicalManager() external returns (RadicalManager);
    function setRadicalManager(address _radicalManager) external;
    function forceTransfer(address to, uint256 tokenId) external;
}
