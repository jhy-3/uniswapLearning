// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
}

