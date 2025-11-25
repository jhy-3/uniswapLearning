# Uniswap V3 实现

这是一个 Uniswap V3 核心功能的简化实现，展示了 V3 与 V2 的关键区别。

## V3 与 V2 的核心区别

### 1. 集中流动性 (Concentrated Liquidity)
- **V2**: 流动性分布在整个价格范围 (0 到无穷大)
- **V3**: 流动性集中在特定价格区间 (tickLower 到 tickUpper)

### 2. 多费用等级 (Multiple Fee Tiers)
- **V2**: 只有一个费用 (0.3%)
- **V3**: 支持多个费用等级 (0.05%, 0.3%, 1%)

### 3. 价格表示方式
- **V2**: 使用 `x * y = k` 恒定乘积公式
- **V3**: 使用 `sqrtPriceX96` (Q64.96 定点数)

### 4. Tick 系统
- **V2**: 连续价格曲线
- **V3**: 离散价格点，基于 tick (price = 1.0001^tick)

### 5. 流动性位置
- **V2**: LP 代币是 ERC20 可互换代币
- **V3**: 每个流动性位置是独立的 NFT

## 编译项目

```bash
cd uniswap-v3
forge build
```

如果遇到编译错误，说明代码中还有一些需要完善的地方。核心架构已经展示出 V3 的关键特性。

## 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-contract UniswapV3FactoryTest

# 显示详细输出
forge test -vvv
```

## 核心合约

### Factory (`src/core/UniswapV3Factory.sol`)
- 支持创建多个不同费用等级的池子
- 为同一对代币可以创建多个池子（不同费用）

### Pool (`src/core/UniswapV3Pool.sol`)
- 集中流动性实现
- Tick 系统管理价格
- 位置管理（每个位置有独立的 tick 范围）

### 库文件
- `TickMath.sol`: Tick 到价格的转换
- `SqrtPriceMath.sol`: 价格数学计算
- `Position.sol`: 位置管理
- `Tick.sol`: Tick 数据结构

## 关键代码位置

### 展示集中流动性的代码
查看 `src/core/UniswapV3Pool.sol` 中的 `mint()` 函数：
```solidity
function mint(
    address recipient,
    int24 tickLower,    // V3: 下限价格 tick
    int24 tickUpper,    // V3: 上限价格 tick
    uint128 amount,
    bytes calldata data
) external override lock returns (uint256 amount0, uint256 amount1)
```

### 展示多费用等级的代码
查看 `src/core/UniswapV3Factory.sol`：
```solidity
// 构造函数中启用多个费用等级
enableFeeAmount(500, 10);   // 0.05% fee
enableFeeAmount(3000, 60);  // 0.3% fee
enableFeeAmount(10000, 200); // 1% fee
```

## 文件结构

```
uniswap-v3/
├── src/
│   ├── core/
│   │   ├── UniswapV3Factory.sol      # 工厂合约
│   │   ├── UniswapV3Pool.sol         # 池子合约
│   │   └── UniswapV3PoolDeployer.sol # 部署器
│   ├── interfaces/                   # 接口定义
│   ├── libraries/                    # 库文件
│   └── periphery/                    # 外围合约（待实现）
├── test/
│   ├── mocks/                        # Mock 合约
│   ├── UniswapV3Factory.t.sol       # Factory 测试
│   └── UniswapV3Pool.t.sol          # Pool 测试
└── TESTING_GUIDE.md                  # 测试指南
```

## 下一步

1. 修复编译错误（主要是类型转换和事件定义）
2. 实现完整的 swap 逻辑（包括 tick 迭代）
3. 实现 SwapRouter 合约
4. 实现 PositionManager (NFT 位置管理)

## 参考

- [Uniswap V3 文档](https://docs.uniswap.org/contracts/v3/overview)
- [V3 白皮书](https://uniswap.org/whitepaper-v3.pdf)
