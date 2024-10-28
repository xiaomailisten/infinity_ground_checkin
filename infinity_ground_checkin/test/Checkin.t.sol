// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Checkin.sol";
import "./TestUtils.sol";

contract MockFailingReceiver {
  receive() external payable {
    revert("Failing receiver");
  }
}

contract CheckinTest is Test, TestUtils {
  Checkin public checkinContract;
  address public user = address(1);
  address public user2 = address(2);
  address public user3 = address(3);

  function setUp() public {
    vm.startPrank(user);
    checkinContract = new Checkin(500, 0.0001 ether, 0.0001 ether);
    vm.stopPrank();
    
    vm.label(user, "User");
    vm.deal(user, 1 ether);
  }

  function testInitialCheckin() public {
    vm.startPrank(user);

    (int64 initialCheckinNum, uint256 initialTimestamp) = checkinContract.getCheckinInfo(user);
    console.log("Initial checkin num:", initialCheckinNum);
    console.log("Initial timestamp:", initialTimestamp);
    
    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);
    console.log("New block timestamp:", block.timestamp);
    
    bool success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "Initial checkin should succeed");
    
    (int64 finalCheckinNum, uint256 finalTimestamp) = checkinContract.getCheckinInfo(user);
    console.log("Final checkin num:", finalCheckinNum);
    console.log("Final timestamp:", finalTimestamp);
    
    assertEq(finalCheckinNum, initialCheckinNum + 1, "Checkin number should increase by 1");
    assertEq(finalTimestamp, newTimestamp, "Timestamp should be updated to current block timestamp");
    
    vm.stopPrank();
  }

  function testCannotCheckinTwiceInOneDay() public {
    vm.startPrank(user);

    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);
      
    bool success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "First checkin should succeed");

    vm.expectRevert(encodeError("CheckinFailed()"));
    checkinContract.checkin();
    vm.stopPrank();
  }

  function testCanCheckinNextDay() public {
    vm.startPrank(user);
    
    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);

    (int64 initialCheckinNum, uint256 initialTimestamp) = checkinContract.getCheckinInfo(user);
    console.log("Initial checkin num:", initialCheckinNum);
    console.log("Initial timestamp:", initialTimestamp);
    console.log("current block timestamp", block.timestamp);
    bool success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "First day checkin should succeed");

    skip(1 days);

    (int64 nextCheckinNum, uint256 nextTimestamp) = checkinContract.getCheckinInfo(user);
    console.log("Next checkin num:", nextCheckinNum);
    console.log("Next timestamp:", nextTimestamp);
    console.log("current block timestamp", block.timestamp);

    success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "Next day checkin should succeed");

    vm.stopPrank();
  }

  function testCheckinInvalidGasFee() public {
    vm.startPrank(user);
    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);
    vm.expectRevert(encodeError("InvalidGasFee()"));
    checkinContract.checkin{value: 0.00009 ether}();
    vm.stopPrank();
  }

  function testCheckinCounter() public {
    vm.startPrank(user);

    uint256 blockTimestamp = block.timestamp;
    vm.warp(blockTimestamp + 1 days);
    for (uint i = 0; i < 3; i++) {
      bool success = checkinContract.checkin{value: 0.0001 ether}();
      assertTrue(success, "Checkin should succeed");
      if (i < 2) skip(1 days);
    }
    (int64 checkinNum, ) = checkinContract.checkinIndexer(user);
    assertEq(checkinNum, 3, "Checkin count should be 3 after 3 days");
    vm.stopPrank();
  }

  function testCheckinWitch12pm() public {
    vm.startPrank(user);
    uint256 blockTimestamp = block.timestamp + 2 days - 1 hours;
    vm.warp(blockTimestamp);
    console.log("blockTimestamp before: ", block.timestamp);
    bool success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "Checkin should succeed");

    vm.warp(blockTimestamp + 1 hours);
    console.log("blockTimestamp after: ", block.timestamp);
    success = checkinContract.checkin{value: 0.0001 ether}();
    assertTrue(success, "Checkin should succeed");
    vm.stopPrank();
  }

  function testCheckinOPEN() public {
    vm.startPrank(user);
    uint256 blockTimestamp = block.timestamp;
    vm.warp(blockTimestamp + 20);
    vm.expectRevert(encodeError("CheckinNotOpen()"));
    checkinContract.checkin{value: 0.0001 ether}();
    vm.stopPrank();
  }

function testWithdrawZeroBalance() public {
    vm.startPrank(user);
    console.log("checkin contract balance before withdraw", checkinContract.getBalance());
    
    uint256 initialBalance = user.balance;
    checkinContract.withdraw();
    uint256 finalBalance = user.balance;
    
    assertEq(initialBalance, finalBalance, "Balance should not change when withdrawing 0");
    assertEq(checkinContract.getBalance(), 0, "Contract balance should remain 0");
    
    vm.stopPrank();
}

  function testWithdrawSuccess() public {
    vm.startPrank(user);
    vm.deal(user, 1 ether);
    checkinContract.deposit{value: 1 ether}();
    console.log("user balance before withdraw", user.balance);
    console.log("checkin contract balance before withdraw", checkinContract.getBalance());
    checkinContract.withdraw();
    console.log("user balance after withdraw", user.balance);
    console.log("checkin contract balance after withdraw", checkinContract.getBalance());
    vm.stopPrank();
  }

  function testGetCheckinInfo() public {
    vm.startPrank(user);
    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);
    checkinContract.checkin{value: 0.0001 ether}();
    (int64 checkinNum, uint256 timestamp) = checkinContract.getCheckinInfo(user);
    assertEq(checkinNum, 1, "Checkin number should be 1");
    assertEq(timestamp, newTimestamp, "Timestamp should be updated to current block timestamp");
    vm.stopPrank();
  }

  function testUpdateCheckinFee() public {
    vm.startPrank(user);
    uint256 newTimestamp = block.timestamp + 1 days;
    vm.warp(newTimestamp);
    checkinContract.updateCheckinFee(0.0002 ether);
    assertEq(checkinContract.checkinFee(), 0.0002 ether, "Checkin fee should be updated to 0.0002 ether");
    vm.stopPrank();
  }

  function testUpdateAdmin() public {
    vm.startPrank(user);
    checkinContract.updateAdmin(user2);
    assertEq(checkinContract.admin(), user2, "Admin should be updated to user2");
    vm.stopPrank();
  }

  function testUpdateGasFee() public {
    vm.startPrank(user);
    checkinContract.updateGasFee(0.0002 ether);
    assertEq(checkinContract.gasFee(), 0.0002 ether, "Gas fee should be updated to 0.0002 ether");
    vm.stopPrank();
  }

  function testSendGasWithAdmin() public {
    vm.startPrank(user);
    checkinContract.deposit{value: 1 ether}();
    checkinContract.updateAdmin(user2);
    vm.startPrank(user2);
    checkinContract.sendGas(user2);
    assertEq(user2.balance, 0.0001 ether, "User2 should receive 0.0001 ether");
    vm.stopPrank();
  }

  function testSendGas() public {
    vm.startPrank(user);
    checkinContract.deposit{value: 1 ether}();
    checkinContract.updateAdmin(user2);
    vm.stopPrank();

    address recipient = address(4);
    uint256 initialBalance = recipient.balance;
    
    vm.prank(user);  // Owner sends gas
    checkinContract.sendGas(recipient);
    
    assertEq(recipient.balance, initialBalance + 0.0001 ether, "Recipient should receive 0.0001 ether");
    
    vm.prank(user2);  // Admin sends gas
    checkinContract.sendGas(recipient);
    
    assertEq(recipient.balance, initialBalance + 0.0002 ether, "Recipient should receive another 0.0001 ether");
  }

  function testSendGasFailed() public {
    vm.startPrank(user3);
    vm.expectRevert(encodeError("InvalidAdmin()"));
    checkinContract.sendGas(user2);
    vm.stopPrank();
  }
  
}
