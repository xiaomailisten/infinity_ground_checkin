// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import { Checkin } from "../src/Checkin.sol";
import { LevelRewards } from "../src/LevelRewards.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract CheckinDeploy is Script {
  function run() public {
    string memory privateKeyStr = vm.envString("PRIVATE_KEY");
    uint256 deployerPrivateKey = vm.parseUint(privateKeyStr);

    address usdtAddress = vm.envAddress("USDT_ADDRESS");

    vm.startBroadcast(deployerPrivateKey);

    Checkin checkin = new Checkin(500, 0.001 ether, 0.0001 ether);
    console.log("Checkin contract deployed at:", address(checkin));

    LevelRewards rewards = new LevelRewards(usdtAddress);
    console.log("LevelRewards contract deployed at:", address(rewards));

    vm.stopBroadcast();
  }
}