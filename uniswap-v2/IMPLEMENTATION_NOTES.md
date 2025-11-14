# Uniswap V2 实现要点和代码结构

这份文档说明了每个合约的关键代码结构和实现要点，帮助你理解如何组织代码。

---

## 1. IERC20 接口 (`src/interfaces/IERC20.sol`)

### 基本结构
```solidity
pragma solidity >=0.5.0;

interface IERC20 {
    // 查询函数
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    
    // 状态改变函数
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    
    // 事件
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
}
```

### 实现要点
- 这是标准的 ERC20 接口
- 只需要定义接口，不需要实现
- 注意使用 `external` 关键字

---

## 2. Math 库 (`src/libraries/Math.sol`)

### 基本结构
```solidity
pragma solidity >=0.5.0;

library Math {
    // 取最小值
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
    
    // 计算平方根（使用 Babylonian 方法）
    // sqrt(x*y) 用于计算流动性
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
```

### 实现要点
- `internal pure` 表示这是一个纯函数
- sqrt 函数用于计算流动性：`liquidity = sqrt(x * y)`
- 也可以使用 Solidity 的 `unchecked` 块（如果版本 >= 0.8.0）

---

## 3. UniswapV2Pair 核心合约 (`src/core/UniswapV2Pair.sol`)

### 基本结构
```solidity
pragma solidity >=0.5.0;

import './interfaces/IERC20.sol';
import './libraries/Math.sol';

contract UniswapV2Pair is IERC20 {
    // ============ 状态变量 ============
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    address public factory;
    address public token0;
    address public token1;
    
    uint112 private reserve0;           // 储备量0（注意：使用112位节省gas）
    uint112 private reserve1;           // 储备量1
    uint32  private blockTimestampLast; // 最后更新时间戳
    
    uint public kLast; // reserve0 * reserve1，用于计算协议手续费
    
    uint public totalSupply; // LP Token 总供应量
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    // ============ 事件 ============
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(...);
    event Sync(uint112 reserve0, uint112 reserve1);
    
    // ============ 核心函数 ============
    
    // 1. 构造函数或初始化函数
    constructor() public {
        factory = msg.sender;
    }
    
    // 2. mint - 添加流动性，铸造 LP Token
    function mint(address to) external returns (uint liquidity) {
        // 获取当前储备量
        // 计算应该注入的代币数量
        // 计算流动性数量：liquidity = sqrt((reserve0 + amount0) * (reserve1 + amount1)) - sqrt(reserve0 * reserve1)
        // 铸造 LP Token
        // 更新储备量
    }
    
    // 3. burn - 移除流动性，销毁 LP Token
    function burn(address to) external returns (uint amount0, uint amount1) {
        // 计算应该返回的代币数量
        // 销毁 LP Token
        // 转账代币
        // 更新储备量
    }
    
    // 4. swap - 代币交换
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external {
        // 验证输出数量
        // 转账输出代币
        // 计算新的储备量
        // 验证恒定乘积公式：(reserve0 - amount0Out) * (reserve1 - amount1Out) >= k
        // 更新储备量
        // 回调（如果data不为空，用于闪电贷等）
    }
    
    // 5. sync - 同步储备量
    function sync() external {
        // 更新储备量为当前余额
    }
    
    // 6. skim - 提取多余的代币
    function skim(address to) external {
        // 提取超出储备量的代币
    }
    
    // 7. getReserves - 获取储备量
    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        return (reserve0, reserve1, blockTimestampLast);
    }
    
    // ERC20 函数实现...
    function _mint(address to, uint value) internal { ... }
    function _burn(address from, uint value) internal { ... }
    function approve(address spender, uint value) external returns (bool) { ... }
    function transfer(address to, uint value) external returns (bool) { ... }
    function transferFrom(address from, address to, uint value) external returns (bool) { ... }
}
```

### 实现要点

#### mint 函数逻辑：
1. 获取当前储备量 `(uint112 _reserve0, uint112 _reserve1) = (reserve0, reserve1)`
2. 获取合约当前余额（可能比储备量多，因为有新的代币转入）
3. 计算新增的储备量：`uint balance0 = IERC20(token0).balanceOf(address(this))`
4. 计算流动性：
   ```solidity
   uint _totalSupply = totalSupply;
   if (_totalSupply == 0) {
       liquidity = Math.sqrt(amount0 * amount1).sub(MINIMUM_LIQUIDITY);
       _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定最小流动性
   } else {
       liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
   }
   ```
5. 验证并铸造 LP Token

#### burn 函数逻辑：
1. 获取当前储备量和总供应量
2. 计算应该返回的代币数量：
   ```solidity
   uint amount0 = liquidity * reserve0 / _totalSupply;
   uint amount1 = liquidity * reserve1 / _totalSupply;
   ```
3. 销毁 LP Token
4. 转账代币
5. 更新储备量

#### swap 函数逻辑：
1. 验证 `amount0Out > 0 || amount1Out > 0`
2. 验证 `(reserve0 - amount0Out) * (reserve1 - amount1Out) >= reserve0 * reserve1`（恒定乘积）
3. 转账输出代币
4. 如果有回调数据，执行回调（支持闪电贷）
5. 更新储备量

### 关键公式

**恒定乘积公式**: `x * y = k`
- 添加流动性时，保持比例不变
- 交换时，K 值不变（不考虑手续费）

**流动性计算**: `liquidity = sqrt(x * y)`
- 第一笔流动性需要减去 `MINIMUM_LIQUIDITY` 并永久锁定

**交换计算**:
- 输入 `amountIn`，输出 `amountOut`
- 考虑手续费（例如 0.3%）：`amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)`

---

## 4. UniswapV2Factory (`src/core/UniswapV2Factory.sol`)

### 基本结构
```solidity
pragma solidity >=0.5.0;

import './UniswapV2Pair.sol';

contract UniswapV2Factory {
    address public feeTo;        // 协议手续费接收地址
    address public feeToSetter;  // 可以设置 feeTo 的地址
    
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;   // 所有交易对地址
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    
    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }
    
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
    
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 1. 验证 tokenA != tokenB
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        
        // 2. 排序 token 地址
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        
        // 3. 验证交易对不存在
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        
        // 4. 使用 CREATE2 部署交易对合约
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        
        // 5. 保存交易对地址
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // 保存反向映射
        allPairs.push(pair);
        
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
    
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
```

### 实现要点
- **地址排序**: 确保 `token0 < token1`，这样可以统一存储顺序
- **CREATE2**: 使用 CREATE2 可以预测交易对的地址，这对库函数 `pairFor` 很重要
- **双重映射**: `getPair[token0][token1]` 和 `getPair[token1][token0]` 都保存，方便查询

---

## 5. UniswapV2Library (`src/libraries/UniswapV2Library.sol`)

### 基本结构
```solidity
pragma solidity >=0.5.0;

import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';

library UniswapV2Library {
    // 对代币地址排序
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }
    
    // 计算交易对地址（使用 CREATE2 预测）
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
            hex'ff',
            factory,
            keccak256(abi.encodePacked(token0, token1)),
            hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // UniswapV2Pair 的 init code hash
        ))));
    }
    
    // 获取储备量
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
    
    // 基础价格计算（不考虑手续费）
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }
    
    // 计算输出数量（考虑 0.3% 手续费）
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;  // 手续费 0.3%，所以是 997/1000
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    // 计算输入数量（考虑 0.3% 手续费）
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;  // +1 是为了向上取整
    }
    
    // 多跳路径：计算输出
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }
    
    // 多跳路径：计算输入
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
```

### 实现要点
- **手续费计算**: 0.3% 手续费意味着实际参与交易的代币是 99.7%（997/1000）
- **多跳路径**: 按照路径顺序逐个交易对计算
- **CREATE2 预测**: `pairFor` 函数需要知道 Pair 合约的 init code hash

---

## 6. UniswapV2Router02 (`src/periphery/UniswapV2Router02.sol`)

### 基本结构
```solidity
pragma solidity >=0.6.6;

import './interfaces/IUniswapV2Router02.sol';
import './UniswapV2Library.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // 只接受从 WETH 合约的回调
    }

    // 内部添加流动性函数
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // 如果交易对不存在，创建它
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            // 第一笔流动性，直接使用 desired 数量
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // 计算最优数量
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    // 添加流动性（ERC20/ERC20）
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    // 添加 ETH 流动性
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IUniswapV2Pair(pair).mint(to);
        // 退还多余的 ETH
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // 内部交换函数
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    // 精确输入代币交换
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    // ETH 相关交换函数...
    // (swapExactETHForTokens, swapTokensForExactETH, 等等)
}
```

### 实现要点
- **滑点保护**: 所有函数都有 `amountMin` 或 `amountOutMin` 参数
- **截止时间**: 使用 `deadline` 参数防止过期交易
- **ETH 处理**: ETH 需要包装成 WETH 才能参与交易
- **多跳路径**: 自动处理多个交易对的路径

---

## 关键概念总结

1. **恒定乘积公式**: `x * y = k`
   - 交换时 K 值不变
   - 添加流动性时，必须保持比例

2. **流动性份额**: `liquidity = sqrt(x * y)`
   - LP Token 数量代表流动性份额

3. **手续费**: 通常 0.3%（997/1000）
   - `amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)`

4. **地址排序**: 确保 `token0 < token1`，统一存储

5. **CREATE2**: 用于预测交易对地址

---

## 安全注意事项

1. **重入攻击**: 在外部调用后更新状态
2. **溢出保护**: 使用 SafeMath 或 Solidity 0.8+
3. **权限控制**: 验证 msg.sender
4. **滑点保护**: 验证最小/最大数量
5. **截止时间**: 防止过期交易

---

现在你有了完整的代码结构参考，可以开始实现了！
