# Uniswap V2 构建步骤清单

这是一个简明的步骤清单，用于跟踪你的实现进度。

## 📦 准备工作

- [ ] 确认 Foundry 已安装（`forge --version`）
- [ ] 确认项目结构已创建
- [ ] 了解 Solidity 基础（0.8+）
- [ ] 了解 Uniswap V2 的基本原理

---

## 🔨 第 1 阶段：基础组件

### Step 1.1: 创建接口
- [ ] 创建 `src/interfaces/IERC20.sol`
  - [ ] 定义 transfer, transferFrom, approve 等函数
  - [ ] 定义 balanceOf, allowance 等查询函数
- **测试**: 无需单独测试，会在后续合约中验证

### Step 1.2: 创建数学库
- [ ] 创建 `src/libraries/Math.sol`
  - [ ] 实现 `min(uint256, uint256)`
  - [ ] 实现 `sqrt(uint256)` 函数（Babylonian 方法）
- [ ] 创建 `test/libraries/Math.t.sol`
  - [ ] 测试 min 函数
  - [ ] 测试 sqrt 函数（各种数值）
- [ ] 运行 `forge test --match-path test/libraries/Math.t.sol`

---

## 🔨 第 2 阶段：核心交易对合约

### Step 2.1: 创建 UniswapV2Pair
- [ ] 创建 `src/core/UniswapV2Pair.sol`
  - [ ] 定义状态变量（reserve0, reserve1, blockTimestampLast 等）
  - [ ] 实现构造函数（或使用 initialize 模式）
  - [ ] 实现 `mint(address)` - 添加流动性
  - [ ] 实现 `burn(address)` - 移除流动性
  - [ ] 实现 `swap(...)` - 代币交换
  - [ ] 实现 `sync()` - 同步储备量
  - [ ] 实现 `skim(address)` - 提取多余代币
  - [ ] 实现 `getReserves()` - 查询储备量
- [ ] 创建测试用的 Mock 代币
  - [ ] 创建 `test/mocks/ERC20.sol`（标准 ERC20 + mint/burn）
- [ ] 创建 `test/core/UniswapV2Pair.t.sol`
  - [ ] 测试添加流动性（mint）
  - [ ] 测试移除流动性（burn）
  - [ ] 测试代币交换（swap）
  - [ ] 测试恒定乘积公式
  - [ ] 测试边界情况
- [ ] 运行 `forge test --match-path test/core/UniswapV2Pair.t.sol`

**关键点**:
- 恒定乘积公式：`reserve0 * reserve1 = k`
- LP Token 计算：`liquidity = sqrt(reserve0 * reserve1)`
- 交换时保持 K 值不变

---

## 🔨 第 3 阶段：工厂合约

### Step 3.1: 创建 UniswapV2Factory
- [ ] 创建 `src/core/UniswapV2Factory.sol`
  - [ ] 定义状态变量（feeTo, feeToSetter, getPair mapping）
  - [ ] 实现构造函数（设置 feeToSetter）
  - [ ] 实现 `createPair(address tokenA, address tokenB)`
    - [ ] 验证 tokenA != tokenB
    - [ ] 验证交易对不存在
    - [ ] 对 token 地址排序
    - [ ] 使用 CREATE2 部署交易对
  - [ ] 实现 `setFeeTo(address)`（权限控制）
  - [ ] 实现 `setFeeToSetter(address)`（权限控制）
- [ ] 创建 `test/core/UniswapV2Factory.t.sol`
  - [ ] 测试创建交易对
  - [ ] 测试防止重复创建
  - [ ] 测试 token 排序
  - [ ] 测试权限控制
- [ ] 运行 `forge test --match-path test/core/UniswapV2Factory.t.sol`

**关键点**:
- 确保 tokenA < tokenB（地址排序）
- 使用 CREATE2 确保可预测的交易对地址

---

## 🔨 第 4 阶段：工具库

### Step 4.1: 创建 UniswapV2Library
- [ ] 创建 `src/libraries/UniswapV2Library.sol`
  - [ ] 实现 `sortTokens(address, address)`
  - [ ] 实现 `pairFor(address factory, address tokenA, address tokenB)`
  - [ ] 实现 `getReserves(...)`
  - [ ] 实现 `quote(...)` - 基础价格计算
  - [ ] 实现 `getAmountOut(...)` - 计算输出（含手续费）
  - [ ] 实现 `getAmountIn(...)` - 计算输入（含手续费）
  - [ ] 实现 `getAmountsOut(...)` - 多跳路径输出
  - [ ] 实现 `getAmountsIn(...)` - 多跳路径输入
- [ ] 创建 `test/libraries/UniswapV2Library.t.sol`
  - [ ] 测试所有价格计算函数
  - [ ] 测试单跳路径
  - [ ] 测试多跳路径
  - [ ] 测试边界情况
- [ ] 运行 `forge test --match-path test/libraries/UniswapV2Library.t.sol`

**关键点**:
- 手续费率通常是 0.3%（997/1000）
- 多跳路径需要逐步计算每个交易对

---

## 🔨 第 5 阶段：路由器合约

### Step 5.1: 准备 WETH 接口
- [ ] 创建 `src/interfaces/IWETH.sol`
  - [ ] 定义 deposit() payable
  - [ ] 定义 withdraw(uint256)
  - [ ] 继承 IERC20

### Step 5.2: 创建 UniswapV2Router02
- [ ] 创建 `src/periphery/UniswapV2Router02.sol`
  - [ ] 定义工厂地址和 WETH 地址
  - [ ] 实现构造函数
  - [ ] 实现 `_addLiquidity(...)` - 内部添加流动性逻辑
  - [ ] 实现 `addLiquidity(...)` - 添加流动性（ERC20/ERC20）
  - [ ] 实现 `addLiquidityETH(...)` - 添加 ETH 流动性
  - [ ] 实现 `removeLiquidity(...)` - 移除流动性
  - [ ] 实现 `removeLiquidityETH(...)` - 移除 ETH 流动性
  - [ ] 实现 `_swap(...)` - 内部交换逻辑
  - [ ] 实现 `swapExactTokensForTokens(...)`
  - [ ] 实现 `swapTokensForExactTokens(...)`
  - [ ] 实现 `swapExactETHForTokens(...)`
  - [ ] 实现 `swapTokensForExactETH(...)`
  - [ ] 实现 `swapExactTokensForETH(...)`
  - [ ] 实现 `swapETHForExactTokens(...)`
  - [ ] 实现辅助函数（_safeTransfer, _safeTransferFrom）
- [ ] 创建测试用的 WETH Mock
  - [ ] 创建 `test/mocks/WETH.sol`
- [ ] 创建 `test/periphery/UniswapV2Router02.t.sol`
  - [ ] 测试所有添加流动性场景
  - [ ] 测试所有移除流动性场景
  - [ ] 测试所有交换场景
  - [ ] 测试滑点保护
  - [ ] 测试权限和安全性
- [ ] 运行 `forge test --match-path test/periphery/UniswapV2Router02.t.sol`

**关键点**:
- ETH 需要包装成 WETH 才能参与交易
- 所有函数都需要滑点保护（amountMin/amountMax）
- 注意重入攻击防护

---

## 🧪 集成测试

### Step 6.1: 完整流程测试
- [ ] 创建 `test/integration/FullFlow.t.sol`
  - [ ] 测试：部署工厂 → 创建交易对 → 添加流动性 → 交换 → 移除流动性
  - [ ] 测试多跳路径交换
  - [ ] 测试 ETH 相关操作
- [ ] 运行 `forge test --match-path test/integration/`

---

## 📋 最终检查清单

- [ ] 所有合约都能编译通过（`forge build`）
- [ ] 所有测试都能通过（`forge test`）
- [ ] 代码格式正确（`forge fmt`）
- [ ] Gas 报告合理（`forge snapshot`）
- [ ] 没有安全漏洞（考虑使用 Slither 等工具）

---

## 🚀 部署脚本（可选）

完成后，你可以创建部署脚本：

- [ ] 创建 `script/Deploy.s.sol`
  - [ ] 部署 Factory
  - [ ] 部署 Router（传入 Factory 和 WETH 地址）
  - [ ] 创建一些测试交易对

运行：`forge script script/Deploy.s.sol --rpc-url <your_rpc> --private-key <your_key>`

---

## 💡 提示

1. **每完成一个步骤就测试**，不要等到最后才测试
2. **遇到问题先看测试错误**，测试会告诉你哪里不对
3. **参考 Uniswap V2 官方代码**，但理解原理更重要
4. **使用 `forge test -vvv`** 查看详细日志
5. **使用 `forge snapshot`** 对比 gas 使用

---

祝你构建顺利！🎉
