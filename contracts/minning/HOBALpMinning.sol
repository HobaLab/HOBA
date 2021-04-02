// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "../ReentrancyGuard.sol";
import "../IHOBANft.sol";

contract HOBALpMinning is ReentrancyGuard, IERC721Receiver, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;

    // Info of each user.
    struct UserInfo {
        EnumerableSet.UintSet nftIds;   // NFT token ids
        uint256 accPoint;               // NFT acc point
        bool withNft;                   // Whether stake nft.

        uint256 amount;             // How many tokens the user has provided.
        uint256 rewardDebt;         // Reward debt. See explanation below.

        // We do some fancy math here. Basically, any point in time, the amount of token
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws NFTs to a pool. Here's what happens:
        //   1. The pool's `accPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each user for special pool that stakes NFTs.
    mapping (uint256 => mapping (address => UserInfo)) private userInfo;

    // Info of each pool.
    struct PoolInfo {
        IERC20 token;               // Address of token contract.
        bool withNft;               // Whether require nft.
        uint256 allocPoint;         // How many allocation points assigned to this pool. Token to distribute per block.
        uint256 lastRewardBlock;    // Last block number that distribution occurs.
        uint256 accPerShare;        // Accumulated per share, times 1e12. See below.
    }
    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Track all added pools.
    mapping(address => bool) public tokenInPool;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    uint256 public tokenPerBlock;           // tokens mined per block. 18 decimal
    IERC20 public hobaToken;                // address of HOBA token contract
    IHOBANft public hobaNft;                // address of HOBA nft contract

    // Block number when bonus period ends.
    uint256 public bonusBeginBlock;
    uint256 public bonusEndBlock;

    // block per day, 20 block per minute at HECO chain
    uint256 public constant BLOCK_PER_DAY = 20 * 60 * 24;

    // mined 365 days
    uint256 public constant MINED_DAYS = 180;

    uint256 public constant MAX_NFTS = 4;

    // nft factor
    uint256 NFT_FACTOR = 100000;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, bool withNft, uint256[] nftIds);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, bool withNft, uint256[] nftIds);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, bool withNft, uint256[] nftIds);

    constructor(address _hobaToken,
        address _hobaNft,
        uint256 _bonusBegin,
        uint256 _tokenPerBlock
    ) {
        hobaToken = IERC20(_hobaToken);
        hobaNft = IHOBANft(_hobaNft);

        bonusBeginBlock = _bonusBegin;
        bonusEndBlock = _bonusBegin.add(BLOCK_PER_DAY.mul(MINED_DAYS));
        tokenPerBlock = _tokenPerBlock;
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function userNftCount(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].nftIds.length();
    }

    function userNftByIndex(address _user, uint256 _pid, uint256 _idx) public view returns (uint256) {
        return userInfo[_pid][_user].nftIds.at(_idx);
    }

    function userAccPoint(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].accPoint;
    }

    function userAmount(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].amount;
    }

    function userWithNft(address _user, uint256 _pid) public view returns (bool) {
        return userInfo[_pid][_user].withNft;
    }

    function userRewardDebt(address _user, uint256 _pid) public view returns (uint256) {
        return userInfo[_pid][_user].rewardDebt;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(uint256 _allocPoint, IERC20 _token, bool _withNft, bool _withUpdate) public onlyOwner {
        require(!tokenInPool[address(_token)], "HOBALpMinning: Token Address already exists in pool");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > bonusBeginBlock? block.number : bonusBeginBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            token: _token,
            withNft: _withNft,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accPerShare: 0
            }));

        tokenInPool[address(_token)] = true;
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function poolAllocPoint(uint256 _pid) public view returns (uint256){
        return poolInfo[_pid].allocPoint;
    }

    // Return reward over the given _from to _to block.
    function getReward(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from > _to || _to < bonusBeginBlock || _from > bonusEndBlock) {
            return 0;
        }

        if (_from <= bonusBeginBlock) {
            _from = bonusBeginBlock;
        }
        if (_to > bonusEndBlock) {
            _to = bonusEndBlock;
        }
        return _to.sub(_from).mul(tokenPerBlock);
    }

    // View function to see pending token on frontend.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPerShare = pool.accPerShare;
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && tokenSupply != 0) {
            uint256 reward = getReward(pool.lastRewardBlock, block.number);
            uint256 poolReward = reward.mul(pool.allocPoint).div(totalAllocPoint);
            accPerShare = accPerShare.add(poolReward.mul(1e12).div(tokenSupply));
        }
        uint256 pending = user.amount.mul(accPerShare).div(1e12).sub(user.rewardDebt);
        return pending.add(pending.mul(user.accPoint).div(NFT_FACTOR));
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 tokenSupply = pool.token.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 reward = getReward(pool.lastRewardBlock, block.number);
        uint256 poolReward = reward.mul(pool.allocPoint).div(totalAllocPoint);
        pool.accPerShare = pool.accPerShare.add(poolReward.mul(1e12).div(tokenSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount, bool _withNft, uint256[] memory _nftIds) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(_nftIds.length <= MAX_NFTS, "HOBALpMinning: more than require count");

        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeTokenTransfer(msg.sender, pending);
            }
        }

        if (_amount > 0) {
            pool.token.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }

        if (pool.withNft) {
            require(_withNft, "HOBANftMinning: Need nft.");
        }

        if (_withNft && !user.withNft) {
            user.withNft = true;

            // update pool accPoint
            for(uint256 i = 0; i < _nftIds.length; i++) {
                hobaNft.safeTransferFrom(_msgSender(), address(this), _nftIds[i]);

                uint256 lVal;
                (, lVal, ) = hobaNft.info(_nftIds[i]);
                user.accPoint = user.accPoint.add(lVal);
                user.nftIds.add(_nftIds[i]);
            }
        }

        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);
        emit Deposit(_msgSender(), _pid, _amount, _withNft, _nftIds);
    }

    function withdraw(uint256 _pid, uint256 _amount, bool _withNFT) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount > 0, "HOBALpMinning: withdraw not good");

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            // calculate nft stake acc
            pending = pending.add(pending.mul(user.accPoint).div(NFT_FACTOR));
            safeTokenTransfer(msg.sender, pending);
        }

        uint256[] memory nftIds = new uint256[](user.nftIds.length());
        if (_amount > 0) {
            if(user.amount == _amount && user.withNft) {
                require(_withNFT, "HOBALpMinning: must withdraw nft");

                user.accPoint = 0;
                user.withNft = false;

                uint256 len = user.nftIds.length();
                for(uint256 i = 0; i < len; i++) {
                    uint256 nftId = user.nftIds.at(0);
                    user.nftIds.remove(nftId);

                    nftIds[i] = nftId;
                    hobaNft.safeTransferFrom(address(this), _msgSender(), nftId);
                }
            }
            user.amount = user.amount.sub(_amount);
            pool.token.safeTransfer(address(msg.sender), _amount);
        }

        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);
        emit Withdraw(_msgSender(), _pid, _amount, _withNFT, nftIds);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.token.safeTransfer(address(msg.sender), user.amount);

        uint256[] memory nftIds = new uint256[](user.nftIds.length());
        if(user.withNft) {
            uint256 len = user.nftIds.length();
            for(uint256 i = 0; i < len; i++) {
                uint256 nftId = user.nftIds.at(0);
                user.nftIds.remove(nftId);

                nftIds[i] = nftId;
                hobaNft.safeTransferFrom(address(this), _msgSender(), nftId);
            }
        }
        user.amount = 0;
        user.accPoint = 0;
        user.rewardDebt = 0;
        user.withNft = false;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount, user.withNft, nftIds);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough TOKENS.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = hobaToken.balanceOf(address(this));
        if (_amount > tokenBal) {
            hobaToken.transfer(_to, tokenBal);
        } else {
            hobaToken.transfer(_to, _amount);
        }
        return;
    }

    function recycleTokens(address _address) public onlyOwner {
        require(_address != address(0), "HOBALpMinning:Invalid address");
        require(hobaToken.balanceOf(address(this)) > 0, "HOBALpMinning:no tokens");
        hobaToken.transfer(_address, hobaToken.balanceOf(address(this)));
    }
}