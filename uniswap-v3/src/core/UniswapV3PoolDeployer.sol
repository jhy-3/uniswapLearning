// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '../interfaces/IUniswapV3Pool.sol';
import '../core/UniswapV3Pool.sol';

/// @title An interface for deploying Uniswap V3 Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
abstract contract UniswapV3PoolDeployer {
    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// Returns factory The factory address
    /// Returns token0 The first token of the pool by address sort order
    /// Returns token1 The second token of the pool by address sort order
    /// Returns fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// Returns tickSpacing The minimum number of ticks between initialized ticks
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        )
    {
        return (
            _factory,
            _token0,
            _token1,
            _fee,
            _tickSpacing
        );
    }

    address private _factory;
    address private _token0;
    address private _token1;
    uint24 private _fee;
    int24 private _tickSpacing;

    /// @notice Deploys a pool with the given parameters by transiently setting the parameters storage slot
    /// and then clearing it after deploying the pool.
    /// @param factory The factory address
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        _factory = factory;
        _token0 = token0;
        _token1 = token1;
        _fee = fee;
        _tickSpacing = tickSpacing;
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete _factory;
        delete _token0;
        delete _token1;
        delete _fee;
        delete _tickSpacing;
    }
}

