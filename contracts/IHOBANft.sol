// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

interface IHOBANft {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function mint(address _to, uint256 _series, uint256 _lVal, uint256 _count) external;
    function stake(uint256 _tokenId) external;
    function info(uint256 tokenId) external view returns (uint256 series, uint256 lVal, uint256 count);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
