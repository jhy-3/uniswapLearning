// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '../interfaces/IUniswapV3Factory.sol';
import '../interfaces/IUniswapV3Pool.sol';
import '../core/UniswapV3Pool.sol';
import '../core/UniswapV3PoolDeployer.sol';

/// @title Uniswap V3 Factory
/// @notice Facilitates creation of Uniswap V3 pools and control over the protocol fees
/// @dev KEY DIFFERENCE FROM V2: V3 supports multiple fee tiers (0.05%, 0.3%, 1%)
/// V2 only had a single fee (0.3%)
contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PoolDeployer {
    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;

    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        // Enable default fee tiers: 0.05%, 0.3%, 1% (V3 KEY FEATURE)
        // V2 only had one fee (0.3% = 3000)
        enableFeeAmount(500, 10);   // 0.05% fee with tick spacing 10
        enableFeeAmount(3000, 60);  // 0.3% fee with tick spacing 60  
        enableFeeAmount(10000, 200); // 1% fee with tick spacing 200
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0, 'fee amount not enabled');
        require(getPool[token0][token1][fee] == address(0), 'pool exists');

        pool = deploy(address(this), token0, token1, fee, tickSpacing);

        getPool[token0][token1][fee] = pool;
        // populate mapping in the reverse direction
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner, 'only owner');
        require(fee < 1000000, 'fee too high');
        // tick spacing is capped at 16384 to prevent the situation where tickSpacing is so large that
        // TickBitmap#nextInitializedTickWithinOneWord overflows
        require(tickSpacing > 0 && tickSpacing < 16384, 'invalid tick spacing');
        require(feeAmountTickSpacing[fee] == 0, 'fee already enabled');

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
}

