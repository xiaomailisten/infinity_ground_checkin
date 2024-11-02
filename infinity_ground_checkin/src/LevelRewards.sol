// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract LevelRewards is Ownable2Step, ReentrancyGuard, Pausable {
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
    event SignerUpdated(address indexed oldSigner, address indexed newSigner);
    
    constructor(address _usdt) Ownable(msg.sender) {
        require(_usdt != address(0), "Zero address");
        usdt = IERC20(_usdt);
        _initializeLevels();
        signer = msg.sender;
    }
    
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Zero address");
        address oldSigner = signer;
        signer = _signer;
        emit SignerUpdated(oldSigner, _signer);
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
        // 计算上次领取的自然日和当前自然日
        uint256 lastClaimDate = userInfo[user].lastClaim / 1 days;
        uint256 currentDate = block.timestamp / 1 days;
        
        // 如果是新的一天，重置每日限额和lastClaim
        if (currentDate > lastClaimDate) {
            userInfo[user].dailyRewards = 0;
            userInfo[user].lastClaim = block.timestamp;
        }
    }

    function claimReward(uint256 amount) external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        require(user.level > 0, "User level not set");
        require(amount > 0, "Invalid amount");
        
        _resetDaily(msg.sender);
        
        Level storage level = levels[user.level];
        require(user.dailyRewards + amount <= level.dailyLimit, "Daily limit exceeded");
        
        user.dailyRewards += amount;
        
        usdt.safeTransfer(msg.sender, amount);
        emit RewardClaimed(msg.sender, amount);
    }
    
    // 管理员功能
    function setUserLevel(address user, uint8 newLevel) external onlyOwner {
        require(newLevel <= 5 && newLevel > 0, "Invalid level");
        userInfo[user].level = newLevel;
        emit LevelSet(user, newLevel);
    }

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
    
    function depositUSDT(uint256 amount) external onlyOwner {
        usdt.safeTransferFrom(msg.sender, address(this), amount);
    }
    
    function withdrawUSDT(uint256 amount) external onlyOwner {
        usdt.safeTransfer(msg.sender, amount);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
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