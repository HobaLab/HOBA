// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract HOBANftSeries is AccessControl, Ownable {
    using SafeMath for uint256;

    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");

    event SeriesAdd(address indexed to, uint256 sid, uint256 qMin, uint256 qMax,
        address currency, uint256 fee, uint256 totalAmount, bool isOpen);
    event SeriesUpdate(address indexed to,  uint256 sid, uint256 qMin, uint256 qMax,
        address currency, uint256 fee, uint256 totalAmount, bool isOpen);

    struct Series {
        uint256 quantityMin;
        uint256 quantityMax;
        address currency;
        uint256 fee;
        uint256 currentAmount;
        uint256 totalAmount;
        bool isOpen;
    }
    mapping (uint256 => Series) public seriesSet;
    mapping (uint256 => bool) public seriesPool;

    uint256 seriesCount;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SELLER_ROLE, _msgSender());
    }

    function addSeries(
        uint256 _sid, uint256 _qMin, uint256 _qMax,
        address _currency, uint256 _fee,
        uint256 _totalAmount, bool _isOpen)
    public {
        require(hasRole(SELLER_ROLE, _msgSender()), "HOBANftSeries: must have seller role");
        require(!seriesPool[_sid], "HOBANftSeries: already have");

        seriesSet[_sid] = Series({
            quantityMin: _qMin,
            quantityMax: _qMax,
            currency: _currency,
            fee: _fee,
            currentAmount: 0,
            totalAmount: _totalAmount,
            isOpen: _isOpen});

        seriesCount = seriesCount+1;
        seriesPool[_sid] = true;

        emit SeriesAdd(_msgSender(), _sid, _qMin, _qMax, _currency, _fee, _totalAmount, _isOpen);
    }

    function updateSeries(
        uint256 _sid, uint256 _qMin, uint256 _qMax,
        address _currency, uint256 _fee,
        uint256 _totalAmount, bool _isOpen)
    public {
        require(hasRole(SELLER_ROLE, _msgSender()), "HOBANftSeries: must have seller role");
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");

        Series storage s = seriesSet[_sid];
        seriesSet[_sid] = Series({
            quantityMin: _qMin,
            quantityMax: _qMax,
            currency: _currency,
            fee: _fee,
            currentAmount: s.currentAmount,
            totalAmount: _totalAmount,
            isOpen: _isOpen});

        emit SeriesUpdate(_msgSender(), _sid, _qMin, _qMax, _currency, _fee, _totalAmount, _isOpen);
    }

    function seriesInfo(uint256 _sid) public view returns (uint256, uint256, address,
        uint256, uint256, uint256, bool) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");

        Series storage s = seriesSet[_sid];
        return (s.quantityMin,
        s.quantityMax,
        s.currency,
        s.fee,
        s.currentAmount,
        s.totalAmount,
        s.isOpen);
    }

    function series() external view returns (uint256) {
        return seriesCount;
    }

    function quantityMin(uint256 _sid) external view returns (uint256) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].quantityMin;
    }

    function quantityMax(uint256 _sid) external view returns (uint256) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].quantityMax;
    }

    function currency(uint256 _sid) external view returns (address) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].currency;
    }

    function fee(uint256 _sid) external view returns (uint256) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].fee;
    }

    function currentAmount(uint256 _sid) external view returns (uint256) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].currentAmount;
    }

    function totalAmount(uint256 _sid) external view returns (uint256) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].totalAmount;
    }

    function isOpen(uint256 _sid) external view returns (bool) {
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");
        return seriesSet[_sid].isOpen;
    }

    function sale(uint256 _sid, uint256 _quantity) external {
        require(hasRole(SELLER_ROLE, _msgSender()), "HOBANftSeries: must have seller role");
        require(seriesPool[_sid], "HOBANftSeries: invalid series id");

        Series storage s = seriesSet[_sid];
        require(s.isOpen, "HOBANftSeries: not open or closed");
        require(s.currentAmount.add(_quantity) <= s.totalAmount, "HOBANftSeries: insufficient amount");
        require(_quantity >= s.quantityMin && _quantity <= s.quantityMax, "HOBANftSeries: quantity limit");

        s.currentAmount = s.currentAmount.add(_quantity);
    }
}
