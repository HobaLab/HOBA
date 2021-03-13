// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./IHOBABoxNft.sol";
import "./IHOBANft.sol";
import "./IHOBANftMeta.sol";
import "./IHOBANftSeries.sol";
import "./IHOBAHashMgr.sol";
import "./UniformRandomNumber.sol";

contract HOBALottery is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    IHOBABoxNft public hobaBox;
    IHOBANft public hobaNft;
    IHOBANftMeta public hobaNftMeta;
    IHOBAHashMgr public hashMgr;
    IHOBANftSeries public hobaNftSeries;
    address payable public wallet;
    address public htToken;

    uint256 public FACTOR = 8;

    constructor(address _hobaBox,
        address _hobaNft,
        address _hobaNftMeta,
        address _hashMgr,
        address _hobaNftSeries,
        address payable _wallet,
        address _htToken
    ) {
        hobaBox = IHOBABoxNft(_hobaBox);
        hobaNft = IHOBANft(_hobaNft);
        hobaNftMeta = IHOBANftMeta(_hobaNftMeta);
        hashMgr = IHOBAHashMgr(_hashMgr);
        hobaNftSeries = IHOBANftSeries(_hobaNftSeries);
        wallet = _wallet;
        htToken = _htToken;

        // pause lottery
        pause();
    }

    function pause() public onlyOwner {
        super._pause();
    }

    function unpause() public onlyOwner{
        super._unpause();
    }

    function setFactor(uint256 _factor) public onlyOwner {
        FACTOR = _factor;
    }

    function _randN(uint256 _seed, uint256 _min, uint256 _max, uint256 _offset) internal pure returns (uint256) {
        require(_max >= _min, "Lottery:randN condition");
        return UniformRandomNumber.uniform(_seed.add(_offset), (_max.sub(_min)).div(2)).add(_min);
    }

    function _randLevel(uint256 _seed, uint256 _max) internal pure returns (uint256) {
        return UniformRandomNumber.uniform(_seed, _max);
    }

    function _weightSlice(uint256 _sid, uint256 _step) private returns (uint256 _sum) {
        uint256 idx = 0;
        for (uint256 i = hobaNftMeta.length(_sid); i > 0; i--) {
            idx++;
            uint256 w = hobaNftMeta.weight(_sid, i-1);
            _sum += w;
            if (idx >= _step) {
                break;
            }
        }
        return _sum;
    }

    function _parseLevel(uint256 _sid, uint256 _weight) private returns(uint256) {
        // cal weight
        uint256[] memory calWeight = new uint256[](hobaNftMeta.length(_sid)+1);
        for(uint256 i = 0; i < hobaNftMeta.length(_sid); i++) {
            calWeight[i] = _weightSlice(_sid, hobaNftMeta.length(_sid)-i);
        }

        uint256 level;
        for (uint256 i = 0; i < calWeight.length; ++i) {
            uint256 w = calWeight[i];
            level = i;
            if(_weight >= w) {
                if(i == 0) {
                    return 1;
                }
                break;
            }
            if(_weight < w) {
                continue;
            }
        }
        return level;
    }

    function _receive(address payable _address, IERC20 _currency, uint256 _amount) private {
        if (address(_currency) != htToken) {
            _currency.transferFrom(_msgSender(), _address, _amount);
        } else {
            _address.transfer(_amount);
        }
    }

    function getBox(uint256 _sid, uint256 _quantity) whenNotPaused nonReentrant public payable {
        _receive(wallet, IERC20(hobaNftSeries.currency(_sid)), hobaNftSeries.fee(_sid).mul(_quantity));
        hobaNftSeries.sale(_sid, _quantity);
        hobaBox.mint(_msgSender(), _sid, _quantity, block.number.add(1));
    }

    function _mint(uint256 _series, uint256 _lVal, uint256 _count) internal {
        hobaNft.mint(_msgSender(), _series, _lVal, _count);
    }

    function _calculate(uint256 _sid, uint256 _blockNumber, uint256 _idx) public returns (uint256 lVal, uint256 count){
        uint256 weight = hobaNftMeta.weightTotal(_sid);
        uint256 hash = hashMgr.getBlockHash(_blockNumber);
        uint256 hs = hash >> 64;
        uint256 seed = hs.add(uint256(_msgSender())).add(hash >> FACTOR.mul(_idx+1));

        // parse level
        uint256 level = _parseLevel(_sid, _randLevel(seed, weight));
        require(level > 0, "Lottery: with error level.");

        uint256 lMin;
        uint256 lMax;
        count = hobaNftMeta.count(_sid, level-1);
        (lMin, lMax) = hobaNftMeta.lVal(_sid, level-1);
        lVal = _randN(seed, uint256(lMin), uint256(lMax), seed >> FACTOR.mul(_idx+1)).toUint32();

        return (lVal, count);
    }

    function openBox(uint256 _tokenId) public {
        require(hobaBox.ownerOf(_tokenId) == _msgSender(), "Lottery: no owner of box");

        uint256 series;
        uint256 quantity;
        uint256 blockNumber;
        (series, quantity, blockNumber) = hobaBox.info(_tokenId);

        // burn box
        hobaBox.burn(_tokenId);

        if(quantity > 1) {
            for (uint256 i = 0; i < quantity; ++i) {
                uint256 luck;
                uint256 count;
                (luck, count) = _calculate(series, blockNumber, i);
                _mint(series, luck, count);
            }

        } else {
            uint256 luck;
            uint256 count;
            (luck, count) = _calculate(series, blockNumber, 1);
            _mint(series, luck, count);
        }
    }

    function setAddress(address _hobaBox,
        address _hobaNft,
        address _hobaNftMeta,
        address _hashMgr,
        address _hobaNftSeries,
        address payable _wallet,
        address _htToken
    ) public onlyOwner {
        hobaBox = IHOBABoxNft(_hobaBox);
        hobaNft = IHOBANft(_hobaNft);
        hobaNftMeta = IHOBANftMeta(_hobaNftMeta);
        hashMgr = IHOBAHashMgr(_hashMgr);
        hobaNftSeries = IHOBANftSeries(_hobaNftSeries);
        wallet = _wallet;
        htToken = _htToken;
    }
}