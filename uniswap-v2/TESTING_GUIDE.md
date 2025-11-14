# Uniswap V2 测试指南

这份指南说明如何测试你的 Uniswap V2 实现，包括代币买卖和 LP 操作。

## 📋 测试文件概览

### 单元测试
- `test/libraries/Math.t.sol` - Math 库测试
- `test/core/UniswapV2Factory.t.sol` - Factory 合约测试
- `test/core/UniswapV2Pair.t.sol` - Pair 核心功能测试

### 集成测试
- `test/integration/UniswapV2Integration.t.sol` - **完整功能测试（推荐从这里开始）**

## 🚀 运行测试

### 运行所有测试
```bash
forge test
```

### 运行集成测试（推荐）
```bash
forge test --match-path "test/integration/*"
```

### 运行特定测试
```bash
# 测试添加流动性
forge test --match-test "testAddLiquidity"

# 测试代币交换
forge test --match-test "testSwapExactTokensForTokens"

# 测试移除流动性
forge test --match-test "testRemoveLiquidity"
```

### 查看详细输出
```bash
forge test -vvv  # 最详细的输出
```

## 📝 测试场景详解

### 1. LP 添加流动性 (testAddLiquidity)

**测试内容：**
- 添加 ERC20/ERC20 流动性
- 验证 LP Token 数量
- 验证储备量

**示例代码：**
```solidity
// 用户授权
tokenA.approve(address(router), amountA);
tokenB.approve(address(router), amountB);

// 添加流动性
(uint amountAUsed, uint amountBUsed, uint liquidity) = router.addLiquidity(
    address(tokenA),
    address(tokenB),
    amountA,        // 期望的 tokenA 数量
    amountB,        // 期望的 tokenB 数量
    0,              // 最小 tokenA 数量（滑点保护）
    0,              // 最小 tokenB 数量（滑点保护）
    user,           // LP Token 接收地址
    block.timestamp + 1000  // 截止时间
);
```

### 2. LP 移除流动性 (testRemoveLiquidity)

**测试内容：**
- 移除流动性
- 验证返回的代币数量
- 验证 LP Token 被销毁

**示例代码：**
```solidity
// 授权 LP Token
pair.approve(address(router), liquidity);

// 移除流动性
(uint amountA, uint amountB) = router.removeLiquidity(
    address(tokenA),
    address(tokenB),
    liquidity,      // LP Token 数量
    0,              // 最小 tokenA 数量
    0,              // 最小 tokenB 数量
    user,           // 代币接收地址
    block.timestamp + 1000
);
```

### 3. ETH 流动性操作

#### 添加 ETH 流动性 (testAddLiquidityETH)
```solidity
token.approve(address(router), amountToken);

(uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: ethAmount}(
    address(token),
    amountToken,
    0,
    0,
    user,
    block.timestamp + 1000
);
```

#### 移除 ETH 流动性 (testRemoveLiquidityETH)
```solidity
pair.approve(address(router), liquidity);

(uint amountToken, uint amountETH) = router.removeLiquidityETH(
    address(token),
    liquidity,
    0,
    0,
    user,
    block.timestamp + 1000
);
```

### 4. 代币交换 (买卖代币)

#### 精确输入交换 (testSwapExactTokensForTokens)
**用精确数量的 tokenA 换取 tokenB**

```solidity
// 准备路径
address[] memory path = new address[](2);
path[0] = address(tokenA);
path[1] = address(tokenB);

// 授权并交换
tokenA.approve(address(router), amountIn);

uint[] memory amounts = router.swapExactTokensForTokens(
    amountIn,           // 输入数量（精确）
    0,                  // 最小输出数量（滑点保护）
    path,
    user,               // 输出接收地址
    block.timestamp + 1000
);
```

#### 精确输出交换 (testSwapTokensForExactTokens)
**用 tokenA 换取精确数量的 tokenB**

```solidity
address[] memory path = new address[](2);
path[0] = address(tokenA);
path[1] = address(tokenB);

tokenA.approve(address(router), type(uint256).max);

uint[] memory amounts = router.swapTokensForExactTokens(
    amountOut,          // 输出数量（精确）
    type(uint256).max,  // 最大输入数量
    path,
    user,
    block.timestamp + 1000
);
```

#### ETH 相关交换

**ETH → Token (testSwapExactETHForTokens)**
```solidity
address[] memory path = new address[](2);
path[0] = address(weth);
path[1] = address(token);

uint[] memory amounts = router.swapExactETHForTokens{value: ethAmount}(
    0,                  // 最小输出数量
    path,
    user,
    block.timestamp + 1000
);
```

**Token → ETH (testSwapTokensForExactETH)**
```solidity
address[] memory path = new address[](2);
path[0] = address(token);
path[1] = address(weth);

token.approve(address(router), type(uint256).max);

uint[] memory amounts = router.swapTokensForExactETH(
    ethAmountOut,       // 精确的 ETH 输出
    type(uint256).max,
    path,
    user,
    block.timestamp + 1000
);
```

### 5. 多跳路径交换 (testMultiHopSwap)

通过多个交易对进行交换，例如：TokenA → TokenB → TokenC

```solidity
address[] memory path = new address[](3);
path[0] = address(tokenA);
path[1] = address(tokenB);
path[2] = address(tokenC);

tokenA.approve(address(router), amountIn);

uint[] memory amounts = router.swapExactTokensForTokens(
    amountIn,
    0,
    path,
    user,
    block.timestamp + 1000
);
```

### 6. 滑点保护 (testSlippageProtection)

确保不会因为价格波动而损失过多：

```solidity
// 如果实际输出小于 amountOutMin，交易会失败
vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,  // 要求的最小输出（如果过高会失败）
    path,
    user,
    block.timestamp + 1000
);
```

### 7. 价格查询 (testGetAmountsOut)

查询交换后能获得多少代币：

```solidity
address[] memory path = new address[](2);
path[0] = address(tokenA);
path[1] = address(tokenB);

uint[] memory amounts = router.getAmountsOut(100 ether, path);
// amounts[0] = 输入数量 (100 ether)
// amounts[1] = 输出数量（扣除手续费后）
```

## 🔍 理解测试结果

### 成功示例
```
[PASS] testAddLiquidity() (gas: 3769288)
[PASS] testSwapExactTokensForTokens() (gas: 3837447)
```

### 失败示例
```
[FAIL: assertion failed] testSwap() (gas: 286030)
```
使用 `-vvv` 查看详细错误信息：
```bash
forge test --match-test "testSwap" -vvv
```

## 💡 编写自己的测试

### 基本模板
```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../../src/core/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../../src/periphery/UniswapV2Router02.sol";
import {ERC20} from "../mocks/ERC20.sol";
import {WETH} from "../mocks/WETH.sol";

contract MyTest is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    WETH weth;
    ERC20 tokenA;
    ERC20 tokenB;
    address user;

    function setUp() public {
        user = makeAddr("user");
        factory = new UniswapV2Factory(address(this));
        weth = new WETH();
        router = new UniswapV2Router02(address(factory), address(weth));
        
        tokenA = new ERC20();
        tokenB = new ERC20();
        tokenA.mint(user, 10000 ether);
        tokenB.mint(user, 10000 ether);
        vm.deal(user, 100 ether);
    }

    function testMyScenario() public {
        vm.startPrank(user);
        // 你的测试代码
        vm.stopPrank();
    }
}
```

## ⚠️ 常见问题

### 1. Init Code Hash 错误
如果看到 `call to non-contract address` 错误，需要更新 init code hash：
```bash
forge script script/GetInitCodeHash.s.sol:GetInitCodeHash
```
然后更新 `UniswapV2Library.sol` 中的 hash。

### 2. ETH 转账失败
确保使用 `makeAddr()` 创建用户地址，而不是硬编码地址：
```solidity
address user = makeAddr("user");  // ✅ 正确
address user = address(0x10);     // ❌ 可能失败
```

### 3. 滑点保护失败
如果 `INSUFFICIENT_OUTPUT_AMOUNT` 错误，降低 `amountOutMin` 或检查池子流动性。

## 📚 下一步

1. **运行所有测试**确保功能正常
2. **阅读测试代码**理解每个场景
3. **编写自己的测试**针对特定用例
4. **查看 Gas 报告**：`forge snapshot`

祝你测试顺利！🎉

