// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "../ReentrancyGuard.sol";
import "../IHOBANft.sol";

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

interface IHOBASupporter {
    function info(address _token) external view returns (address, uint256, uint256, bool);
    function isSupport(address _token) external view returns (bool);
}

contract HOBASender is ReentrancyGuard, IERC721Receiver, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    event Send(address indexed from, address indexed to, address token, uint256 amount, bool withNft, uint256 nftId);
    event Accept(address indexed from, address indexed to, address token, uint256 amount, bool withNft, uint256 nftId);
    event Claim(address indexed from, address token, uint256 amount, bool withNft, uint256 nftId);

    IERC20  public hobaToken;
    IHOBANft public hobaNft;
    IHOBARedPacket public hobaRp;
    IHOBASupporter public hobaSuppoter;
    mapping (address => bool) public receiverMinning;

    uint256 public FACTOR_A = 10000;
    uint256 public FACTOR_B = 6;

    constructor(address _token, address _nft, address _rp, address _supporter) {
        hobaToken = IERC20(_token);
        hobaNft = IHOBANft(_nft);
        hobaRp = IHOBARedPacket(_rp);
        hobaSuppoter = IHOBASupporter(_supporter);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setFactor(uint256 _factorA, uint256 _factorB) public onlyOwner {
        FACTOR_A = _factorA;
        FACTOR_B = _factorB;
    }

    receive() external payable { }

    function send(address _to, address _token, uint256 _amount, bool _withNft, uint256 _nftId) public payable {
        require(_to != _msgSender(), "HOBASender:must send to other");
        require(hobaSuppoter.isSupport(_token), "HOBASender:not support token");
        if (_token == address(0)) {
            _amount = msg.value;
        }
        uint256 amountMin;
        uint256 amountMax;
        ( , amountMin, amountMax, ) = hobaSuppoter.info(_token);
        require(_amount >= amountMin , "HOBASender:less than min amount");
        require(_amount <= amountMax , "HOBASender:more than max amount");

        if (_token != address(0)) {
            IERC20(_token).safeTransferFrom(_msgSender(), address(this), _amount);
        } else {
            address(this).transfer(_amount);
        }
        hobaNft.safeTransferFrom(_msgSender(), address(this), _nftId);

        // mint red packet
        hobaRp.mint(address(this), _msgSender(), _to, _token, _amount, _withNft, _nftId);
        emit Send(_msgSender(), _to, _token, _amount, _withNft, _nftId);
    }

    function accept(uint256 _packetId) public nonReentrant {
        address _from;
        address _to;
        address _rpToken;
        uint256 _amount;
        bool _withNft;
        uint256 _nftId;
        uint256 _expiredBlock;
        (_from, _to, _rpToken, _amount, _withNft, _nftId, _expiredBlock) = hobaRp.info(_packetId);
        require(_to == _msgSender(), "HOBASender:invalid acceptor");
        require(block.number <= _expiredBlock, "HOBASender:red packet expired");

        hobaRp.burn(_packetId);

        uint256 lVal;
        uint256 count;
        (, lVal, count) = hobaNft.info(_nftId);
        if (count > 0 && !receiverMinning[_msgSender()]) {
            hobaNft.stake(_nftId);
            receiverMinning[_msgSender()] = true;

            hobaToken.safeTransfer(_from, lVal.mul(1e18).div(FACTOR_A).mul(FACTOR_B).div(10).mul(8));
            hobaToken.safeTransfer(_to, lVal.mul(1e18).div(FACTOR_A).mul(FACTOR_B).div(10).mul(2));
        }

        if (_rpToken == address(0)) {
            _msgSender().transfer(_amount);
        } else {
            IERC20(_rpToken).safeTransfer(_msgSender(), _amount);
        }
        if(_withNft) {
            hobaNft.safeTransferFrom(address(this), _msgSender(), _nftId);
        } else {
            hobaNft.safeTransferFrom(address(this), _from, _nftId);
        }
        emit Accept(_msgSender(), _to, _rpToken, _amount, _withNft, _nftId);
    }

    function claim(uint256 _packetId) public nonReentrant {
        address _from;
        address _to;
        address _rpToken;
        uint256 _amount;
        bool _withNft;
        uint256 _nftId;
        uint256 _expiredBlock;
        (_from, _to, _rpToken, _amount, _withNft, _nftId, _expiredBlock) = hobaRp.info(_packetId);
        require(_from == _msgSender(), "HOBASender: invalid claimer");
        require(block.number > _expiredBlock, "HOBASender:red packet not expired");

        hobaRp.burn(_packetId);

        if (_rpToken == address(0)) {
            _msgSender().transfer(_amount);
        } else {
            IERC20(_rpToken).safeTransfer(_msgSender(), _amount);
        }
        hobaNft.safeTransferFrom(address(this), _msgSender(), _nftId);
        emit Claim(_msgSender(), _rpToken, _amount, _withNft, _nftId);
    }

    function recycleTokens(address _address) public onlyOwner {
        require(_address != address(0), "HOBASender: invalid address");
        require(hobaToken.balanceOf(address(this)) > 0, "HOBASender: sufficient balance");
        hobaToken.safeTransfer(_address, hobaToken.balanceOf(address(this)));
    }

    function setAddress(address _rp, address _supporter) public onlyOwner {
        hobaRp = IHOBARedPacket(_rp);
        hobaSuppoter = IHOBASupporter(_supporter);
    }
}
