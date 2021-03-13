// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./IHOBANftMeta.sol";

abstract contract HOBANftMetaBase is IHOBANftMeta, Ownable {
    using SafeMath for uint256;

    uint256 seriesCount;
    mapping(uint256 => uint256) public seriesWeights;

    // events
    event MetaAdd(address indexed to, uint256 sid, uint256 lMin, uint256 lMax,
        uint256 weight, uint256 count);
    event MetaUpdate(address indexed to, uint256 sid, uint256 idx,
        uint256 lMin, uint256 lMax, uint256 weight, uint256 count);

    // base info
    struct MetaInfo {
        // lucky
        uint256 lMin;
        uint256 lMax;
        uint256 weight;
        uint256 count;
    }
    // series id metaInfo map
    mapping(uint256 => MetaInfo[]) public seriesMeta;

    /**
     * @dev addMeta.
     * Requirements: only owner, when paused.
     * @notice add new meta info to contract
     * @param _lMin The min lucky value
     * @param _lMax The max lucky value
     * @param _weight The meta weight
     * @param _count The meta count
     */
    function addMeta (uint256 _sid, uint256 _lMin, uint256 _lMax, uint256 _weight, uint256 _count)
    onlyOwner public {
        seriesMeta[_sid].push(MetaInfo({
            lMin: _lMin,
            lMax: _lMax,
            weight: _weight,
            count: _count
            }));

        seriesWeights[_sid] = seriesWeights[_sid].add(_weight);
        seriesCount = seriesCount+1;
        emit MetaAdd(_msgSender(), _sid, _lMin, _lMax, _weight, _count);
    }

    /**
     * @dev updateMeta.
     * Requirements: only owner, when paused.
     * @notice update special level meta info
     * @param _idx The meta index
     * @param _lMin The min lucky value
     * @param _lMax The max lucky value
     * @param _weight The weight of the meta
     * @param _count The count of the meta
     */
    function updateMeta (uint256 _sid, uint256 _idx, uint256 _lMin, uint256 _lMax, uint256 _weight, uint256 _count)
    onlyOwner public {
        require(_idx < length(_sid), "HOBALotteryMeta: invalid index.");

        MetaInfo storage m = seriesMeta[_sid][_idx];
        seriesWeights[_sid] = seriesWeights[_sid].sub(m.weight).add(_weight);

        seriesMeta[_sid][_idx] = MetaInfo({
            lMin: _lMin,
            lMax: _lMax,
            weight: _weight,
            count: _count
            });

        emit MetaUpdate(_msgSender(), _sid, _idx, _lMin, _lMax, _weight, _count);
    }

    /**
     * @dev series.
     * @notice get series count
     */
    function series() public view override returns (uint256) {
        return seriesCount;
    }

    function length(uint256 _sid) public view override returns (uint256) {
        return seriesMeta[_sid].length;
    }

    function lVal(uint256 _sid, uint256 _idx) public view override returns  (uint256, uint256) {
        return (seriesMeta[_sid][_idx].lMin, seriesMeta[_sid][_idx].lMax);
    }

    function weight(uint256 _sid, uint256 _idx) public view override returns (uint256) {
        return seriesMeta[_sid][_idx].weight;
    }

    function count(uint256 _sid, uint256 _idx) public view override returns (uint256) {
        return seriesMeta[_sid][_idx].count;
    }

    function weightTotal(uint256 _sid) public view override returns (uint256) {
        return seriesWeights[_sid];
    }

    function meta(uint256 _sid, uint256 _idx) public view override returns (uint256, uint256, uint256, uint256){
        MetaInfo storage m = seriesMeta[_sid][_idx];
        return (m.lMin, m.lMax, m.weight, m.count);
    }
}
