# Uniswap V3 测试指南

本文档介绍如何编译和测试 Uniswap V3 的核心功能。

## 前提条件

- Foundry 已安装
- Solidity 0.8.30+

## 编译项目

```bash
cd uniswap-v3
forge build
```

## 运行测试

### 1. 运行所有测试
```bash
forge test
```

### 2. 运行特定测试文件
```bash
# 测试 Factory
forge test --match-contract UniswapV3FactoryTest

# 测试 Pool
forge test --match-contract UniswapV3PoolTest
```

### 3. 显示详细输出
```bash
forge test -vvv  # 显示详细日志
```

## 核心功能测试

### V3 与 V2 的关键区别演示

#### 1. 多费用等级 (Multiple Fee Tiers)

**V2**: 只有一个费用 (0.3%)  
**V3**: 支持多个费用等级 (0.05%, 0.3%, 1%)

```solidity
// V3 可以为同一对代币创建不同费用的池子
factory.createPool(token0, token1, 500);   // 0.05% fee
factory.createPool(token0, token1, 3000);  // 0.3% fee  
factory.createPool(token0, token1, 10000); // 1% fee
```

测试：`testCreatePoolDifferentFeeTiers()`

#### 2. 集中流动性 (Concentrated Liquidity)

**V2**: 流动性分布在整个价格范围 (0 到无穷大)  
**V3**: 流动性集中在特定价格区间 (tickLower 到 tickUpper)

```solidity
// V3 添加流动性时需要指定价格范围
int24 tickLower = -60;  // 下限价格 tick
int24 tickUpper = 60;   // 上限价格 tick
uint128 liquidity = 1000 * 1e18;
pool.mint(recipient, tickLower, tickUpper, liquidity, data);
```

测试：`testMintConcentratedLiquidity()`

#### 3. 价格表示方式

**V2**: 使用 `x * y = k` 恒定乘积公式  
**V3**: 使用 `sqrtPriceX96` (Q64.96 定点数)

```solidity
// V3 价格表示为 sqrtPriceX96
(uint160 sqrtPriceX96, int24 tick) = pool.slot0();
// price = (sqrtPriceX96 / 2^96)^2
```

测试：`testPriceRepresentation()`

#### 4. Tick 系统

**V2**: 连续价格曲线  
**V3**: 离散价格点，基于 tick (price = 1.0001^tick)

```solidity
// V3 价格必须是 tick spacing 的倍数
int24 tickSpacing = pool.tickSpacing(); // 通常是 10, 60, 或 200
```

测试：`testTickSpacing()`

## 测试流程

### 1. 设置环境
```bash
cd uniswap-v3
forge build
```

### 2. 运行 Factory 测试
验证 Factory 可以创建多个不同费用的池子：
```bash
forge test --match-test testCreatePoolDifferentFeeTiers -vvv
```

### 3. 运行 Pool 测试
验证集中流动性和价格系统：
```bash
forge test --match-test testMintConcentratedLiquidity -vvv
```

## 常见问题

### 编译错误
如果遇到编译错误，检查：
1. Solidity 版本是否匹配 (0.8.30+)
2. 所有依赖是否已安装 (`forge install`)

### 测试失败
如果测试失败：
1. 使用 `-vvv` 查看详细日志
2. 检查 Mock 代币余额是否充足
3. 确认价格范围设置合理

## 关键概念说明

### Tick 和价格
- Tick 是离散的价格点
- 价格 = 1.0001^tick
- Tick spacing 确保价格只能在特定间隔移动

### 集中流动性
- LP 可以在特定价格区间提供流动性
- 如果价格移出区间，该位置的流动性不再参与交易
- 需要 LP 主动管理价格区间

### 费用等级
- 0.05%: 适合稳定币对
- 0.3%: 标准交易对 (与 V2 相同)
- 1%: 适合波动性大的交易对

## 下一步

1. 实现 SwapRouter 合约进行交换
2. 实现 PositionManager 管理流动性位置 (NFT)
3. 实现完整的 swap 逻辑，包括 tick 迭代

## 参考

- [Uniswap V3 文档](https://docs.uniswap.org/contracts/v3/overview)
- [V3 白皮书](https://uniswap.org/whitepaper-v3.pdf)

