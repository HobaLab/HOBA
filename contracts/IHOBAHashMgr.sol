// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

interface IHOBAHashMgr {
    function getBlockHash(uint256 blockNumber) external returns(uint256);
}
