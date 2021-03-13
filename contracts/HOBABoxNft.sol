// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HOBABoxNft is ERC721PresetMinterPauserAutoId, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;

    struct MetaInfo {
        uint256 series;
        uint256 quantity;
        uint256 blockNumber;
    }
    mapping (uint256 => MetaInfo) public metaSet;
    Counters.Counter private tokenIdTracker;

    constructor () ERC721PresetMinterPauserAutoId("HOBABoxNft", "HOBABox", "") {
    }

    function setBaseURI(string memory _baseURI) onlyOwner public {
        _setBaseURI(_baseURI);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) onlyOwner public {
        _setRoleAdmin(role, adminRole);
    }

    function mint(address _to, uint256 _sid, uint256 _quantity, uint256 _blockNumber) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "HOBABoxNft: must have minter role to mint");

        _mint(_to, tokenIdTracker.current());
        metaSet[tokenIdTracker.current()] = MetaInfo(_sid, _quantity, _blockNumber);
        tokenIdTracker.increment();
    }

    function burn(uint256 tokenId) public override {
        require(hasRole(MINTER_ROLE, _msgSender()), "HOBABoxNft: must have minter role to mint");

        super.burn(tokenId);
        delete metaSet[tokenId];
    }

    function mint(address /*_to*/) public view onlyOwner override(ERC721PresetMinterPauserAutoId) {
        require(false, "HOBABoxNft: not supported");
    }

    function info(uint256 tokenId) public view returns (uint256, uint256, uint256) {
        require(_exists(tokenId), "HOBABoxNft: URI query for nonexistent token");

        MetaInfo storage m = metaSet[tokenId];
        return (m.series, m.quantity, m.blockNumber);
    }
}
