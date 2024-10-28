// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";


struct checkinInfo {
  int64 checkinNum;
  uint256 lastCheckinTimestamp;
}

contract Checkin is Ownable {
  uint256 public startTimestamp;
  uint256 public checkinFee; // checkin fee
  address public admin;
  uint256 public gasFee; // transfergas fee

  mapping (address => checkinInfo) public checkinIndexer;
    
  error CheckinNotOpen();
  error CheckinFailed();
  error InvalidAdmin();
  error InvalidGasFee();
  error SendFailed();

  event CheckinEvent(address indexed user, int64 checkinNum, uint256 timestamp);

  constructor(uint256 startTimestamp_, uint256 checkinFee_, uint256 gasFee_) Ownable(msg.sender) {
      startTimestamp = startTimestamp_;
      checkinFee = checkinFee_;
      gasFee = gasFee_;
  }

  function validateCheckin(checkinInfo memory info) internal view returns (bool) {  
    if (block.timestamp < startTimestamp) {
      revert CheckinNotOpen();
    }

    uint256 currentTimestamp = block.timestamp;
    uint256 lastCheckinDate = info.lastCheckinTimestamp / 1 days;
    uint256 currentDate = currentTimestamp / 1 days;
    return currentDate > lastCheckinDate;
  } 

  function checkin() external payable returns (bool) {
    checkinInfo storage info = checkinIndexer[msg.sender];
    if (!validateCheckin(info)) {
      revert CheckinFailed();
    }
    if (msg.value < checkinFee) {
      revert InvalidGasFee();
    }

    info.checkinNum++;
    info.lastCheckinTimestamp = block.timestamp;
    emit CheckinEvent(msg.sender, info.checkinNum, block.timestamp);
    return true;
  }

  function getCheckinInfo(address user) external view returns (int64, uint256) {
    checkinInfo memory info = checkinIndexer[user];
    return (info.checkinNum, info.lastCheckinTimestamp);
  }

  function updateCheckinFee(uint256 newCheckinFee) external onlyOwner {
    checkinFee = newCheckinFee;
  }
  
  function withdraw() external payable onlyOwner {
    (bool success, ) = payable(owner()).call{value: address(this).balance}("");
    if (!success) {
      revert SendFailed();
    }
  }

  function updateAdmin(address newAdmin) external onlyOwner {
    admin = newAdmin;
  }
  
  function updateGasFee(uint256 newGasFee) external onlyOwner {
    gasFee = newGasFee;
  }

  function getBalance() external view returns (uint256) {
    return address(this).balance;
  }

  function sendGas(address to) external {
    if (msg.sender != admin && msg.sender != owner()) {
      revert InvalidAdmin();
    }
    payable(to).transfer(gasFee);
  }

  function deposit() external payable onlyOwner {}  

  receive() external payable {}
}