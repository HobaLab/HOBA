// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IHOBARedPacket {
    function mint(address _owner, address _from, address _to, address _token, uint256 _amount,
        bool _withNft, uint256 _nftId) external;
    function burn(uint256 tokenId) external;

    function info(uint256 _tokenId) external view returns(
        address _from, address _to,
        address _token, uint256 _amount,
        bool _withNf, uint256 _nftId,
        uint256 _expiredBlockNumber
    );
}

contract HOBARedPacket is IHOBARedPacket, ERC721PresetMinterPauserAutoId, Ownable {
    using Address for address;
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    // 24hours 3 seconds per block
    uint256 public EXPIRED_BLOCK = 20 * 60 * 24;

    struct Packet {
        address from;
        address to;
        address token;
        uint256 amount;
        bool withNft;
        uint256 nftId;
        uint256 expiredBlockNumber;
    }
    mapping (uint256 => Packet) public packetSet;
    Counters.Counter private tokenIdTracker;
    mapping (address => EnumerableSet.UintSet) private senderPackets;
    mapping (address => EnumerableSet.UintSet) private receiverPackets;

    constructor () ERC721PresetMinterPauserAutoId("HOBARedPacket", "HOBARP", "") {
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) onlyOwner public {
        _setRoleAdmin(role, adminRole);
    }

    function balanceOfSender(address _owner) public view returns (uint256) {
        require(_owner != address(0), "HOBARedPacket:bos: query for the zero address");
        return senderPackets[_owner].length();
    }

    function tokenOfOwnerByIndexSender(address _owner, uint256 _index) public view returns (uint256) {
        return senderPackets[_owner].at(_index);
    }

    function balanceOfReceiver(address _owner) public view returns (uint256) {
        require(_owner != address(0), "HOBARedPacket:bor: query for the zero address");
        return receiverPackets[_owner].length();
    }

    function tokenOfOwnerByIndexReceiver(address _owner, uint256 _index) public view returns (uint256) {
        return receiverPackets[_owner].at(_index);
    }

    function setExpiredBlockNumber(uint256 _expiredBlock) public onlyOwner {
        EXPIRED_BLOCK = _expiredBlock;
    }

    function mint(address _owner, address _from, address _to,
        address _token, uint256 _amount,
        bool _withNft, uint256 _nftId) public override {
        require(hasRole(MINTER_ROLE, _msgSender()), "HOBARedPacket: must have minter role to mint");

        uint256 packetId = tokenIdTracker.current();
        _mint(_owner, packetId);

        packetSet[packetId] = Packet(_from, _to,
            _token, _amount,
            _withNft, _nftId,
            block.number.add(EXPIRED_BLOCK));

        senderPackets[_from].add(packetId);
        receiverPackets[_to].add(packetId);

        tokenIdTracker.increment();
    }

    function mint(address /*_to*/) public view onlyOwner override(ERC721PresetMinterPauserAutoId) {
        require(false, "HOBARedPacket: not supported");
    }

    function burn(uint256 _tokenId) public override(ERC721Burnable,IHOBARedPacket) {
        require(hasRole(MINTER_ROLE, _msgSender()), "HOBARedPacket: must have minter role to burn");
        require(_exists(_tokenId), "HOBARedPacket:burn: nonexistent token");

        super.burn(_tokenId);

        // remove
        Packet storage p = packetSet[_tokenId];
        senderPackets[p.from].remove(_tokenId);
        receiverPackets[p.to].remove(_tokenId);

        delete packetSet[_tokenId];
    }

    function info(uint256 _tokenId) public override view returns (address, address, address, uint256, bool, uint256, uint256) {
        require(_exists(_tokenId), "HOBARedPacket:info: nonexistent token");
        Packet storage p = packetSet[_tokenId];
        return (p.from, p.to, p.token, p.amount, p.withNft, p.nftId, p.expiredBlockNumber);
    }
}
