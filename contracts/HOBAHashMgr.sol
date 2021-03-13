// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HOBAHashMgr is AccessControl, Ownable {
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    mapping (uint256 => uint256) internal hashSet;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CONFIG_ROLE, _msgSender());
    }

    function store(uint256 n, bytes32 hash) public {
        require(hasRole(CONFIG_ROLE, _msgSender()), "HOBAHashMgr: must have config role");
        uint256 hs = uint256(blockhash(n));
        if (hs <= 0) {
            hs = uint256(hash);
            require(hs > 0, "wrong hash");
            hashSet[n] = uint256(hash);
        } else {
            hashSet[n] = hs;
        }
    }

    function getBlockHash(uint256 blockNumber) external view returns(uint256) {
        uint256 hash = uint256(blockhash(blockNumber));
        if (hash <= 0) {
            hash = hashSet[blockNumber];
        }
        require(hash > 0, "blockhash failed");
        return hash;
    }
}
