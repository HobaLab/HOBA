// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

interface IHOBANftSeries {
    function series() external view returns (uint256);
    function quantityMin(uint256 _sid) external view returns (uint256);
    function quantityMax(uint256 _sid) external view returns (uint256);
    function currency(uint256 _sid) external view returns (address);
    function fee(uint256 _sid) external view returns (uint256);
    function currentAmount(uint256 _sid) external view returns (uint256);
    function totalAmount(uint256 _sid) external view returns (uint256);
    function isOpen(uint256 _sid) external view returns (bool);
    function sale(uint256 _sid, uint256 _quantity) external;
}
