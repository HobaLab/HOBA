// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IHOBASupporter {
    function info(address _token) external view returns (address, uint256, uint256, bool);
    function isSupport(address _token) external view returns (bool);
}

contract HOBASupporter is IHOBASupporter, AccessControl, Ownable {
    using SafeMath for uint256;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    event TokenAdd(address indexed to, address token, uint256 min, uint256 max, bool isOpen);
    event TokenUpdate(address indexed to,  address token, uint256 min, uint256 max, bool isOpen);
    event TokenRemove(address indexed to, address token);

    struct Tokens {
        address token;
        uint256 amountMin;
        uint256 amountMax;
        bool isOpen;
    }
    mapping (address => Tokens) public tokensSet;
    mapping (address => bool) public tokensPool;
    uint256 public TokensCount;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CONFIG_ROLE, _msgSender());
    }

    function addToken(address _token, uint256 _min, uint256 _max, bool _isOpen) public {
        require(hasRole(CONFIG_ROLE, _msgSender()), "HOBASupporter: must have config role");
        require(!tokensPool[_token], "HOBASupporter: already have");
        require(_min <= _max, "HOBASupporter: already have");

        tokensSet[_token] = Tokens({
            token: _token,
            amountMin: _min,
            amountMax: _max,
            isOpen: _isOpen});

        TokensCount = TokensCount.add(1);
        tokensPool[_token] = true;

        emit TokenAdd(_msgSender(), _token, _min, _max, _isOpen);
    }

    function updateToken(address _token, uint256 _min, uint256 _max, bool _isOpen) public {
        require(hasRole(CONFIG_ROLE, _msgSender()), "HOBASupporter: must have config role");
        require(tokensPool[_token], "HOBASupporter: invalid token");

        tokensSet[_token] = Tokens({
            token: _token,
            amountMin: _min,
            amountMax: _max,
            isOpen: _isOpen});

        emit TokenUpdate(_msgSender(), _token, _min, _max, _isOpen);
    }

    function removeToken(address _token) public {
        require(hasRole(CONFIG_ROLE, _msgSender()), "HOBASupporter: must have config role");
        require(tokensPool[_token], "HOBASupporter: invalid token");

        delete tokensPool[_token];
        delete tokensSet[_token];

        TokensCount = TokensCount.sub(1);
        emit TokenRemove(_msgSender(), _token);
    }

    function isSupport(address _token) public override view returns(bool) {
        if (tokensPool[_token]) {
            return tokensSet[_token].isOpen;
        }
        return false;
    }

    function info(address _token) external override view returns (address, uint256, uint256, bool) {
        require(tokensPool[_token], "HOBASupporter: invalid token");
        Tokens storage t = tokensSet[_token];
        return (t.token, t.amountMin, t.amountMax, t.isOpen);
    }
}
