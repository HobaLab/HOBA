// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "./HOBANftMetaBase.sol";

contract HOBANftMeta is HOBANftMetaBase {
    constructor() {
        addMeta(0, 4000, 4500, 25000, 4);
        addMeta(0, 4500, 5000, 25000, 4);
        addMeta(0, 5000, 6000, 20000, 5);
        addMeta(0, 6000, 8000, 15000, 6);
        addMeta(0, 8000, 9000, 10000, 8);
        addMeta(0, 9000, 10000, 5000, 10);
    }
}
