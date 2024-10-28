// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract LevelRewards is Ownable(msg.sender), ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    
    IERC20 public usdt;
    address public signer;
    
    struct Level {
        uint256 dailyLimit;
        uint256 weeklyLimit;
        uint256 multiplier;
    }
    
    struct UserInfo {
        uint8 level;          // 用户等级
        uint256 dailyRewards; // 当日已领取数量
        uint256 lastClaim;    // 上次领取时间
    }
    
    mapping(uint8 => Level) public levels;
    mapping(address => UserInfo) public userInfo;
    
    event RewardClaimed(address indexed user, uint256 amount);
    event LevelSet(address indexed user, uint8 level);
    event LevelConfigUpdated(uint8 level, uint256 dailyLimit, uint256 weeklyLimit, uint256 multiplier);
    
    constructor(address _usdt) {
        usdt = IERC20(_usdt);
        _initializeLevels();
        signer = msg.sender;
    }
    
    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function _initializeLevels() internal {
        levels[1] = Level(2e18, 8e18, 1);
        levels[2] = Level(4e18, 16e18, 2);
        levels[3] = Level(10e18, 40e18, 3);
        levels[4] = Level(20e18, 80e18, 4);
        levels[5] = Level(50e18, 200e18, 5);
    }
    
    // 重置每日限额
    function _resetDaily(address user) internal {
        if (block.timestamp >= userInfo[user].lastClaim + 1 days) {
            userInfo[user].dailyRewards = 0;
        }
    }
    
    // 用户领取奖励
    function claimReward(uint256 amount) external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        require(user.level > 0, "User level not set");
        require(amount > 0, "Invalid amount");
        
        _resetDaily(msg.sender);
        
        Level storage level = levels[user.level];
        require(user.dailyRewards + amount <= level.dailyLimit, "Daily limit exceeded");
        
        user.dailyRewards += amount;
        user.lastClaim = block.timestamp;
        
        usdt.safeTransfer(msg.sender, amount);
        emit RewardClaimed(msg.sender, amount);
    }
    
    // 管理员功能
    
    // 简历版 设置用户等级
    function setUserLevel(address user, uint8 newLevel) external onlyOwner {
        require(newLevel <= 5 && newLevel > 0, "Invalid level");
        userInfo[user].level = newLevel;
        emit LevelSet(user, newLevel);
    }

    // 完整版 设置用户等级
    function setLevelWithSignature(
        address user,
        uint8 newLevel,
        bytes memory signature
    ) external {
        require(user == msg.sender, "Not authorized");

        bytes32 message = keccak256(abi.encodePacked(user, newLevel));
        bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address recoveredSigner = signedHash.recover(signature);
        
        require(recoveredSigner == signer, "Invalid signature");
        require(newLevel > 0 && newLevel <= 5, "Invalid level");

        userInfo[user].level = newLevel;
        emit LevelSet(user, newLevel);
    }
    
    // // 设置等级配置
    // function setLevelConfig(
    //     uint8 level,
    //     uint256 dailyLimit,
    //     uint256 weeklyLimit,
    //     uint256 multiplier
    // ) external onlyOwner {
    //     require(level > 0 && level <= 5, "Invalid level");
    //     require(weeklyLimit >= dailyLimit * 7, "Weekly limit must be >= daily limit * 7");
        
    //     levels[level] = Level(dailyLimit, weeklyLimit, multiplier);
    //     emit LevelConfigUpdated(level, dailyLimit, weeklyLimit, multiplier);
    // }
    
    // 存入USDT
    function depositUSDT(uint256 amount) external onlyOwner {
        usdt.safeTransferFrom(msg.sender, address(this), amount);
    }
    
    // 提取USDT
    function withdrawUSDT(uint256 amount) external onlyOwner {
        usdt.safeTransfer(msg.sender, amount);
    }
    
    // 紧急暂停/恢复
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // 查看功能
    function getUserLevel(address user) external view returns (UserInfo memory) {
        return userInfo[user];
    }
    
    function getLevelInfo(uint8 level) external view returns (Level memory) {
        return levels[level];
    }
    
    function getContractBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
}