// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

interface IHOBABoxNft {
    function mint(address _to, uint256 _sid, uint256 _quantity, uint256 _blockNumber) external;
    function burn(uint256 tokenId) external;
    function info(uint256 tokenId) external view returns (uint256, uint256, uint256);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
