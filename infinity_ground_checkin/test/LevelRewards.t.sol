// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LevelRewards.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract LevelRewardsTest is Test {
    LevelRewards public rewards;
    MockUSDT public usdt;
    
    address public owner;
    address public user1;
    address public user2;
    
    uint256 private signerPrivateKey;
    address private signerAddress;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        usdt = new MockUSDT();
        rewards = new LevelRewards(address(usdt));
        
        usdt.approve(address(rewards), type(uint256).max);
        rewards.depositUSDT(100000 * 10 ** usdt.decimals());
        
        usdt.transfer(user1, 1000 * 10 ** usdt.decimals());
        usdt.transfer(user2, 1000 * 10 ** usdt.decimals());
        
        vm.prank(user1);
        usdt.approve(address(rewards), type(uint256).max);
        vm.prank(user2);
        usdt.approve(address(rewards), type(uint256).max);

        signerPrivateKey = 0xA11CE;  // 测试私钥
        signerAddress = vm.addr(signerPrivateKey);
        
        rewards.setSigner(signerAddress);
    }
    
    // 测试建议版本签名设置等级
    function testSetUserLevel() public {
        rewards.setUserLevel(user1, 2);
        
        LevelRewards.UserInfo memory userInfo = rewards.getUserLevel(user1);
        assertEq(userInfo.level, 2);
    }
    
    function testSetLevelWithSignature() public {
        address user = user1;
        uint8 newLevel = 2;
        
        bytes32 message = keccak256(abi.encodePacked(user, newLevel));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message)));
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(user);
        rewards.setLevelWithSignature(user, newLevel, signature);
        
        LevelRewards.UserInfo memory userInfo = rewards.getUserLevel(user);
        assertEq(userInfo.level, newLevel);
    }
    
    function testWrongUserWithSignature() public {
        address user = user1;
        uint8 newLevel = 2;
        
        // 为user1创建签名
        bytes32 message = keccak256(abi.encodePacked(user, newLevel));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message)));
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // user2尝试使用user1的签名和地址
        vm.prank(user2);
        vm.expectRevert("Not authorized");
        rewards.setLevelWithSignature(user1, newLevel, signature);
    }

    // 测试无效签名
    function testInvalidSignature() public {
        address user = user1;
        uint8 newLevel = 2;
        
        // 使用错误的私钥签名
        uint256 wrongPrivateKey = 0xB0B;
        bytes32 message = keccak256(abi.encodePacked(user, newLevel));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message)));
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(user);
        vm.expectRevert("Invalid signature");
        rewards.setLevelWithSignature(user, newLevel, signature);
    }

    function testClaimReward() public {
        rewards.setUserLevel(user1, 1);
        
        uint256 claimAmount = 1 * 10 ** 18;
        uint256 balanceBefore = usdt.balanceOf(user1);
        
        vm.prank(user1);
        rewards.claimReward(claimAmount);
        
        uint256 balanceAfter = usdt.balanceOf(user1);
        assertEq(balanceAfter - balanceBefore, claimAmount);
    }
    

    function testDailyLimitDos() public {
        uint256 entryProtocolTime = 1000;
        
        rewards.setUserLevel(user1, 1);
        vm.startPrank(user1);
        
        vm.warp(entryProtocolTime);
        rewards.claimReward(1 * 10 ** 18);

        vm.warp(entryProtocolTime + 1 days - 1);
        rewards.claimReward(0.9 * 10 ** 18);
        vm.warp(entryProtocolTime + 2 days - 100);
        rewards.claimReward(0.9 * 10 ** 18);
    }
    

    function testDailyLimitReset() public {
        rewards.setUserLevel(user1, 1);
        
        vm.prank(user1);
        rewards.claimReward(1 * 10 ** 18);
        
        vm.warp(block.timestamp + 1 days);
        
        vm.prank(user1);
        rewards.claimReward(1 * 10 ** 18);
    }
    

    function testPause() public {
        rewards.setUserLevel(user1, 1);
        
        rewards.pause();
        
        vm.prank(user1);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        rewards.claimReward(1 * 10 ** 18);
        
        rewards.unpause();
        
        vm.prank(user1);
        rewards.claimReward(1 * 10 ** 18);
    }
    
    function testUnauthorizedAccess() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user1
            )
        );
        rewards.setUserLevel(user2, 1);
        
        vm.prank(user2);
        vm.expectRevert("User level not set");
        rewards.claimReward(1 * 10 ** 18);
    }
    
    function testInvalidParameters() public {
        vm.expectRevert("Invalid level");
        rewards.setUserLevel(user1, 0);
        
        vm.expectRevert("Invalid level");
        rewards.setUserLevel(user1, 6);
        
        rewards.setUserLevel(user1, 1);
        vm.prank(user1);
        vm.expectRevert("Invalid amount");
        rewards.claimReward(0);
    }
}