# Checkin & Rewards 合约

这是一个基于 BSC 测试网的用户签到和等级奖励系统，使用 Foundry 框架开发。

## 项目准备

### 环境配置

安装 Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

克隆项目后安装依赖:

```bash
git clone <项目地址>
cd <项目目录>
forge install OpenZeppelin/openzeppelin-contracts
```

创建环境配置文件 `.env`:

参考 `.env.example` 文件，参数在 `script/deploy.sol` 文件中用到，设置到主网时请更换变量。

```.env
# 管理者的私钥，注意0x开头
PRIVATE_KEY=

# 测试网的RPC地址，可以从ChainList里搜索
BSC_RPC_URL=https://bsc-testnet-rpc.publicnode.com

# 测试网中的USDT地址
BSC_USDT_ADDRESS=0x5Edcc27AD022551fA16CE1AC9EdB3baB99e1da2D

# 主网的RPC地址
# BNB_MAINNET_RPC=

# 主网的USDT地址
#BNB_USDT_ADDRESS=0x55d398326f99059fF775485246999027B3197955
```

### BSC 测试网配置

获取测试网 BNB (tBNB)，用作部署合约等的 gas 费用，部署到主网上需要真实 BNB，这里提供测试网代笔 tBNB 的获取方式:

- 访问 BSC 的 Discord 社区，根据指引领取 tBNB: https://discord.gg/bnbchain
- 访问 [BSC Testnet Faucet](https://testnet.bnbchain.org/faucet-smart)
- 访问 [Quicknode BSC Faucet](https://faucet.quicknode.com/binance-smart-chain/bnb-testnet)

配置 MetaMask 添加 BSC 测试网:

- 网络名称: BSC Testnet
- RPC URL 参考: https://bsc-testnet-rpc.publicnode.com （可以从 Chainlist 获取）
- 链 ID: 97
- 货币符号: tBNB
- 区块浏览器: https://testnet.bscscan.com （查看交易具体信息）

## 项目测试

运行所有测试:

```bash
forge test
```

查看详细测试输出:

```bash
forge test -vv
```

查看测试覆盖率:

```bash
forge coverage
```

## 合约部署

编译合约:

```bash
forge build
```

部署到 BSC 测试网:

注意里面的 rpc-url 不一定有用，可以更换其他

```bash
forge script script/deploy.sol contracts --rpc-url https://bsc-testnet-rpc.publicnode.com --broadcast
```

## Level Rewards 的等级说明

| 等级 | 等级 | 每日提现限额 | 每周提现限额 | 积分加成倍率 |
|------|------|--------------|--------------|--------------|
| 初级 | Beginner | 2 USDT | 8 USDT | 1 |
| 中级 | Intermediate | 4 USDT | 16 USDT | 2 |
| 高级 | Advanced | 10 USDT | 40 USDT | 3 |
| 大师 | Master | 20 USDT | 80 USDT | 4 |
| 巅峰 | Legend | 50 USDT | 200 USDT | 5 |

## Rewards 合约的前端示例

项目包含一个 `index.html` 示例文件，展示了如何与合约交互。使用步骤：

启动本地服务器:

```bash
python -m http.server 8080
# or
npx http-server
```

访问 `http://localhost:8080`

## 重要函数说明

### Rewards 合约中 setLevelWithSignature 函数

这是一个带签名验证的等级设置函数，用于安全地更新用户等级。

合约函数:

```solidity
function setLevelWithSignature(
    address user,
    uint8 newLevel,
    bytes memory signature
) external {
    require(msg.sender == user, "Not authorized");

    bytes32 message = keccak256(abi.encodePacked(user, newLevel));
    bytes32 signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
    address recoveredSigner = signedHash.recover(signature);

    require(recoveredSigner == signer, "Invalid signature");
    require(newLevel > 0 && newLevel <= 5, "Invalid level");

    userInfo[user].level = newLevel;
    emit LevelSet(user, newLevel);
}
```

后端签名示例 (Node.js):

```javascript
const ethers = require("ethers");

const SIGNER_PRIVATE_KEY = process.env.SIGNER_PRIVATE_KEY;
const wallet = new ethers.Wallet(SIGNER_PRIVATE_KEY);

async function signLevelUpdate(userAddress, newLevel) {
  const message = ethers.utils.solidityKeccak256(["address", "uint8"], [userAddress, newLevel]);

  const signature = await wallet.signMessage(ethers.utils.arrayify(message));
  return signature;
}

// API示例
app.post("/api/update-level", async (req, res) => {
  const { userAddress } = req.body;
  const newLevel = 2; // 根据业务逻辑决定新等级

  try {
    const signature = await signLevelUpdate(userAddress, newLevel);
    res.json({ signature, newLevel });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

前端调用示例:

```javascript
async function updateUserLevel() {
  try {
    // 1. 从后端获取签名
    const response = await fetch("/api/update-level", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userAddress: userAddress }),
    });

    const { signature, newLevel } = await response.json();

    // 2. 调用合约
    const tx = await contract.setLevelWithSignature(userAddress, newLevel, signature);
    await tx.wait();

    console.log("Level updated successfully");
  } catch (error) {
    console.error("Error:", error);
  }
}
```

### CheckIn 合约的构造体

```solidity
  constructor(uint256 startTimestamp_, uint256 checkinFee_, uint256 gasFee_) Ownable(msg.sender) {
      startTimestamp = startTimestamp_;
      checkinFee = checkinFee_;
      gasFee = gasFee_;
  }
```

1. startTimestamp: time user can check in

2. checkinFee: fee charged from user when checking in

3. gasFee: can send gas to user
