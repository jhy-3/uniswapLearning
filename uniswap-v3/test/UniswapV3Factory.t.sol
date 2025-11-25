// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import 'forge-std/Test.sol';
import '../src/core/UniswapV3Factory.sol';
import '../src/interfaces/IUniswapV3Pool.sol';
import './mocks/ERC20.sol';

/// @title Test Uniswap V3 Factory
/// @notice Tests V3 Factory functionality, demonstrating key differences from V2
contract UniswapV3FactoryTest is Test {
    UniswapV3Factory factory;
    ERC20 token0;
    ERC20 token1;

    function setUp() public {
        factory = new UniswapV3Factory();
        token0 = new ERC20('Token0', 'T0', 1000000 * 1e18);
        token1 = new ERC20('Token1', 'T1', 1000000 * 1e18);
    }

    /// @notice Test creating pools with different fee tiers (V3 KEY FEATURE)
    /// @dev V2: Only one fee tier (0.3%)
    /// V3: Multiple fee tiers (0.05%, 0.3%, 1%)
    function testCreatePoolDifferentFeeTiers() public {
        // Create pool with 0.3% fee (standard tier)
        address pool3000 = factory.createPool(address(token0), address(token1), 3000);
        assertTrue(pool3000 != address(0), 'Pool should be created');
        assertEq(IUniswapV3Pool(pool3000).fee(), 3000, 'Fee should be 3000 (0.3%)');

        // V3 KEY DIFFERENCE: Can create pools with different fees for same token pair
        // V2: Only one pool per token pair
        // V3: Multiple pools per token pair (different fee tiers)
        address pool500 = factory.createPool(address(token0), address(token1), 500);
        assertTrue(pool500 != address(0), 'Second pool should be created');
        assertEq(IUniswapV3Pool(pool500).fee(), 500, 'Fee should be 500 (0.05%)');

        // Verify both pools exist and are different
        assertTrue(pool3000 != pool500, 'Pools should be different addresses');
        assertEq(factory.getPool(address(token0), address(token1), 3000), pool3000);
        assertEq(factory.getPool(address(token0), address(token1), 500), pool500);
    }

    function testFactoryOwner() public {
        assertEq(factory.owner(), address(this), 'Test contract should be owner');
    }

    function testFeeAmountTickSpacing() public {
        // Verify default fee tiers are enabled
        assertEq(factory.feeAmountTickSpacing(500), 10, '0.05% fee should have tick spacing 10');
        assertEq(factory.feeAmountTickSpacing(3000), 60, '0.3% fee should have tick spacing 60');
        assertEq(factory.feeAmountTickSpacing(10000), 200, '1% fee should have tick spacing 200');
    }
}

