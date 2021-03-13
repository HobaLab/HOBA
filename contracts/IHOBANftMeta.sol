// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

interface IHOBANftMeta {
    /**
     * @dev series.
     * @notice get series count
     */
    function series() external returns (uint256);

    /**
     * @dev length.
     * @notice get special series length
     */
    function length(uint256 _sid) external returns (uint256);

    /**
     * @dev lVal.
     * @notice get special series idx lucky value
     */
    function lVal(uint256 _sid, uint256 _idx) external returns (uint256, uint256);

    /**
     * @dev weight.
     * @notice get special series idx weight
     */
    function weight(uint256 _sid, uint256 _idx) external returns (uint256);

    /**
     * @dev count.
     * @notice get special series idx count
     */
    function count(uint256 _sid, uint256 _idx) external returns (uint256);


    /**
     * @dev weightTotal.
     * @notice get special series total weight
     */
    function weightTotal(uint256 _sid) external returns (uint256);

    /**
     * @dev meta.
     * @notice get special series meta lMin, lMax, weight, count
     */
    function meta(uint256 _sid, uint256 _idx) external view returns (uint256, uint256, uint256, uint256);
}
