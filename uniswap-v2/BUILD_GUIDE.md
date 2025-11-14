# Uniswap V2 从零到一构建指南

## 📋 概述

本指南将指导你从零开始构建 Uniswap V2 的核心功能。我们使用 Foundry 作为开发框架，按照模块化的方式逐步构建。

## 🎯 核心功能

Uniswap V2 的核心包括：
1. **UniswapV2Factory** - 工厂合约，用于创建交易对
2. **UniswapV2Pair** - 交易对合约（LP Token）
3. **UniswapV2Router02** - 路由器合约，提供用户友好的接口
4. **UniswapV2Library** - 数学计算库

---

## 📁 文件结构规划

```
src/
├── core/
│   ├── UniswapV2Pair.sol          # 交易对核心合约（LP Token）
│   └── UniswapV2Factory.sol       # 工厂合约
├── periphery/
│   └── UniswapV2Router02.sol      # 路由器合约
└── libraries/
    └── UniswapV2Library.sol       # 数学计算库
```

---

## 🚀 构建步骤

### 阶段 1: 基础库和接口（第 1 步）

#### 1.1 创建接口文件

**位置**: `src/interfaces/IERC20.sol`

**目的**: 定义 ERC20 代币标准接口

**需要实现的功能**:
- `totalSupply()` - 总供应量
- `balanceOf(address)` - 查询余额
- `transfer(address, uint256)` - 转账
- `transferFrom(address, address, uint256)` - 授权转账
- `approve(address, uint256)` - 授权
- `allowance(address, address)` - 查询授权额度

**测试位置**: 这一步可以不需要单独测试，会在后续合约测试中验证

---

#### 1.2 创建数学库

**位置**: `src/libraries/Math.sol`

**目的**: 提供安全的数学计算（防止溢出）

**需要实现的功能**:
- `min(uint256 x, uint256 y)` - 取最小值（使用 SafeMath 或内置的 unchecked）
- `sqrt(uint256 y)` - 开平方根（用于计算恒定乘积公式）

**测试位置**: `test/libraries/Math.t.sol`

**测试要点**:
- 测试 min 函数
- 测试 sqrt 函数的准确性

---

### 阶段 2: 核心合约 - UniswapV2Pair（第 2 步）

#### 2.1 创建 UniswapV2Pair 合约

**位置**: `src/core/UniswapV2Pair.sol`

**目的**: 这是 Uniswap V2 的核心，代表一个交易对（如 ETH/USDT）

**核心功能**:

1. **状态变量**:
   - `reserve0, reserve1` - 两种代币的储备量
   - `blockTimestampLast` - 最后更新时间戳
   - `price0CumulativeLast, price1CumulativeLast` - 累计价格（用于预言机）
   - `kLast` - 最后的 K 值（用于计算协议手续费）

2. **核心函数**:
   - `mint(address)` - 铸造 LP Token（添加流动性）
   - `burn(address)` - 销毁 LP Token（移除流动性）
   - `swap(uint amount0Out, uint amount1Out, address to, bytes calldata data)` - 交换代币
   - `sync()` - 同步储备量
   - `skim(address)` - 提取多余的代币
   - `getReserves()` - 获取储备量

3. **恒定乘积公式**: `x * y = k`
   - 添加流动性: 确保 `(reserve0 + amount0) * (reserve1 + amount1) >= reserve0 * reserve1`
   - 交换: `(reserve0 - amount0Out) * (reserve1 - amount1Out) >= k`

**依赖**: 
- IERC20 接口
- Math 库

**测试位置**: `test/core/UniswapV2Pair.t.sol`

**测试要点**:
- 测试添加流动性（mint）
- 测试移除流动性（burn）
- 测试代币交换（swap）
- 测试恒定乘积公式的正确性
- 测试滑点保护
- 测试手续费计算（如果有）

---

### 阶段 3: 工厂合约 - UniswapV2Factory（第 3 步）

#### 3.1 创建 UniswapV2Factory 合约

**位置**: `src/core/UniswapV2Factory.sol`

**目的**: 用于创建和管理交易对

**核心功能**:

1. **状态变量**:
   - `feeTo` - 协议手续费接收地址
   - `feeToSetter` - 可以设置 feeTo 的地址
   - `getPair[token0][token1]` - 获取交易对地址的映射

2. **核心函数**:
   - `createPair(address tokenA, address tokenB)` - 创建交易对
   - `setFeeTo(address)` - 设置手续费接收地址（仅 feeToSetter 可调用）
   - `setFeeToSetter(address)` - 设置 feeToSetter（仅当前 feeToSetter 可调用）

3. **注意事项**:
   - 确保 tokenA != tokenB
   - 确保交易对不存在
   - 对 tokenA 和 tokenB 进行排序（确保 tokenA < tokenB）

**依赖**: 
- UniswapV2Pair 合约

**测试位置**: `test/core/UniswapV2Factory.t.sol`

**测试要点**:
- 测试创建交易对
- 测试防止创建重复交易对
- 测试 token 排序
- 测试权限控制（setFeeTo, setFeeToSetter）

---

### 阶段 4: 工具库 - UniswapV2Library（第 4 步）

#### 4.1 创建 UniswapV2Library 库

**位置**: `src/libraries/UniswapV2Library.sol`

**目的**: 提供路由器和外部调用者使用的工具函数

**核心功能**:

1. **排序函数**:
   - `sortTokens(address tokenA, address tokenB)` - 对两个代币地址排序
   - `pairFor(address factory, address tokenA, address tokenB)` - 计算交易对地址（使用 CREATE2）

2. **储备量查询**:
   - `getReserves(address factory, address tokenA, address tokenB)` - 获取交易对储备量

3. **价格计算**:
   - `quote(uint amountA, uint reserveA, uint reserveB)` - 根据储备量计算另一个代币的数量
   - `getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)` - 计算输出数量（考虑手续费）
   - `getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)` - 计算输入数量（考虑手续费）

4. **多跳路径计算**:
   - `getAmountsOut(address factory, uint amountIn, address[] memory path)` - 计算多跳路径的输出
   - `getAmountsIn(address factory, uint amountOut, address[] memory path)` - 计算多跳路径的输入

**依赖**: 
- UniswapV2Factory 接口
- Math 库

**测试位置**: `test/libraries/UniswapV2Library.t.sol`

**测试要点**:
- 测试排序函数
- 测试价格计算函数
- 测试单跳和多跳路径计算
- 测试边界情况（零储备量、大数值等）

---

### 阶段 5: 路由器合约 - UniswapV2Router02（第 5 步）

#### 5.1 创建 UniswapV2Router02 合约

**位置**: `src/periphery/UniswapV2Router02.sol`

**目的**: 提供用户友好的接口，隐藏底层复杂性

**核心功能**:

1. **添加流动性**:
   - `addLiquidity(...)` - 添加流动性
   - `addLiquidityETH(...)` - 添加 ETH 流动性（payable）
   - `_addLiquidity(...)` - 内部添加流动性逻辑

2. **移除流动性**:
   - `removeLiquidity(...)` - 移除流动性
   - `removeLiquidityETH(...)` - 移除 ETH 流动性
   - `removeLiquidityWithPermit(...)` - 使用签名移除流动性（EIP-2612）

3. **交换代币**:
   - `swapExactTokensForTokens(...)` - 精确输入代币交换
   - `swapTokensForExactTokens(...)` - 精确输出代币交换
   - `swapExactETHForTokens(...)` - ETH 精确输入交换
   - `swapTokensForExactETH(...)` - 精确输出 ETH 交换
   - `swapExactTokensForETH(...)` - 精确输入换取 ETH
   - `swapETHForExactTokens(...)` - ETH 换取精确数量代币
   - `_swap(...)` - 内部交换逻辑

4. **辅助函数**:
   - `_safeTransfer(...)` - 安全转账
   - `_safeTransferFrom(...)` - 安全授权转账

**依赖**: 
- UniswapV2Factory
- UniswapV2Library
- IERC20
- IWETH（Wrapped ETH 接口）

**注意**: 需要引入 WETH（Wrapped ETH）合约或使用现有实现

**测试位置**: `test/periphery/UniswapV2Router02.t.sol`

**测试要点**:
- 测试所有添加流动性的场景
- 测试所有移除流动性的场景
- 测试所有交换场景
- 测试滑点保护
- 测试权限和重入保护

---

## 🧪 测试策略

### 单元测试
- 每个合约和库都应该有独立的测试文件
- 测试正常流程和边界情况
- 测试错误情况和权限控制

### 集成测试
创建 `test/integration/` 目录，测试完整流程：
1. 部署工厂合约
2. 创建交易对
3. 添加流动性
4. 执行交换
5. 移除流动性

---

## 📝 实现顺序建议

**建议的实现和测试顺序**：

1. ✅ **第 1 步**: 创建接口和基础库（IERC20, Math）
   - 编写并测试 Math 库

2. ✅ **第 2 步**: 实现 UniswapV2Pair
   - 先实现基本结构
   - 实现 mint 函数并测试
   - 实现 burn 函数并测试
   - 实现 swap 函数并测试

3. ✅ **第 3 步**: 实现 UniswapV2Factory
   - 实现创建交易对功能
   - 实现权限控制功能

4. ✅ **第 4 步**: 实现 UniswapV2Library
   - 实现所有计算函数
   - 与 UniswapV2Pair 和 Factory 集成测试

5. ✅ **第 5 步**: 实现 UniswapV2Router02
   - 先实现添加/移除流动性
   - 再实现交换功能
   - 完整集成测试

---

## 🔧 辅助文件

### Mock 代币合约（测试用）

**位置**: `test/mocks/ERC20.sol`

**目的**: 用于测试的 ERC20 代币实现

**功能**:
- 标准 ERC20 功能
- `mint(address, uint256)` - 铸造代币
- `burn(address, uint256)` - 销毁代币

---

## 📚 参考资源

- [Uniswap V2 文档](https://docs.uniswap.org/contracts/v2/overview)
- [Uniswap V2 核心合约源码](https://github.com/Uniswap/v2-core)
- [Uniswap V2 路由器源码](https://github.com/Uniswap/v2-periphery)

---

## 💡 关键概念提醒

1. **恒定乘积公式**: `x * y = k`
   - 添加流动性时保持比例不变
   - 交换时 K 值不变（或略有增加，如果有手续费）

2. **流动性份额**: LP Token 代表用户对流动性的所有权
   - `liquidity = sqrt(x * y)`
   - 添加流动性时，LP 数量 = `sqrt((reserve0 + amount0) * (reserve1 + amount1)) - sqrt(reserve0 * reserve1)`

3. **滑点保护**: 用户需要指定最小/最大数量，防止 MEV 攻击

4. **手续费**: 
   - 默认 0.3% 的交易手续费
   - 可以设置协议手续费（通常给流动性提供者或协议）

---

## ⚠️ 注意事项

1. **安全性**:
   - 始终检查重入攻击
   - 验证输入参数
   - 使用 SafeMath 或 Solidity 0.8+ 的溢出保护

2. **Gas 优化**:
   - 合理使用 storage 和 memory
   - 考虑使用 packed structs

3. **测试完整性**:
   - 覆盖所有函数
   - 测试边界情况
   - 测试失败场景

---

现在你可以开始按照这个指南逐步实现每个部分。记住：**先实现，再测试，确保每一步都正确后再进行下一步**！

如果遇到问题，可以随时询问我。
