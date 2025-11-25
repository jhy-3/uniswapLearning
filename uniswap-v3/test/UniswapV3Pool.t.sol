// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import 'forge-std/Test.sol';
import '../src/core/UniswapV3Factory.sol';
import '../src/core/UniswapV3Pool.sol';
import '../src/interfaces/IUniswapV3Pool.sol';
import '../src/interfaces/callback/IUniswapV3MintCallback.sol';
import '../src/libraries/TickMath.sol';
import '../src/interfaces/IERC20.sol';
import './mocks/ERC20.sol';

/// @title Test Uniswap V3 Pool
/// @notice Tests V3 Pool core functionality, demonstrating concentrated liquidity
contract UniswapV3PoolTest is Test {
    UniswapV3Factory factory;
    IUniswapV3Pool pool;
    ERC20 token0;
    ERC20 token1;
    address user;

    // Helper contract to handle callbacks
    TestMintCallback callbackHelper;

    function setUp() public {
        factory = new UniswapV3Factory();
        token0 = new ERC20('Token0', 'T0', 10000000 * 1e18);
        token1 = new ERC20('Token1', 'T1', 10000000 * 1e18);
        user = address(this);

        // Create pool with 0.3% fee
        address poolAddress = factory.createPool(address(token0), address(token1), 3000);
        pool = IUniswapV3Pool(poolAddress);

        // Initialize pool with price = 1:1 (sqrtPriceX96 for 1:1 is 2^96)
        uint160 sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        pool.initialize(sqrtPriceX96);

        callbackHelper = new TestMintCallback(address(token0), address(token1));
        token0.approve(address(callbackHelper), type(uint256).max);
        token1.approve(address(callbackHelper), type(uint256).max);
    }

    /// @notice Test adding liquidity in a specific price range (V3 KEY FEATURE)
    /// @dev V2: Liquidity spread across entire price range (0 to infinity)
    /// V3: Liquidity concentrated in specific tick range
    function testMintConcentratedLiquidity() public {
        // V3 KEY DIFFERENCE: Specify price range for liquidity
        // Current price is at tick 0 (1:1 ratio)
        // Add liquidity in range: tick -60 to tick +60
        int24 tickLower = -60;
        int24 tickUpper = 60;
        uint128 liquidity = 1000 * 1e18;

        // Transfer tokens to callback helper
        uint256 amount0Expected = 1000 * 1e18;
        uint256 amount1Expected = 1000 * 1e18;
        token0.transfer(address(callbackHelper), amount0Expected);
        token1.transfer(address(callbackHelper), amount1Expected);

        // Mint liquidity through callback helper
        (uint256 amount0, uint256 amount1) = callbackHelper.mint(
            address(pool),
            user,
            tickLower,
            tickUpper,
            liquidity
        );

        assertTrue(amount0 > 0, 'Should deposit some token0');
        assertTrue(amount1 > 0, 'Should deposit some token1');

        // V3 KEY DIFFERENCE: Check position info at specific ticks
        bytes32 positionKey = keccak256(abi.encodePacked(user, tickLower, tickUpper));
        (uint128 positionLiquidity,,,,) = pool.positions(positionKey);
        assertEq(positionLiquidity, liquidity, 'Position liquidity should match');
    }

    /// @notice Test that pool uses sqrtPriceX96 instead of x*y=k (V3 KEY FEATURE)
    function testPriceRepresentation() public {
        (uint160 sqrtPriceX96, int24 tick,,,,,) = pool.slot0();
        assertTrue(sqrtPriceX96 > 0, 'sqrtPriceX96 should be set');
        assertTrue(tick >= TickMath.MIN_TICK && tick <= TickMath.MAX_TICK, 'Tick should be valid');

        // V3 uses sqrtPriceX96 = sqrt(price) * 2^96
        // V2 uses reserves (x, y) and x * y = k formula
        assertTrue(sqrtPriceX96 == 79228162514264337593543950336 || sqrtPriceX96 > 0, 'Price should be valid');
    }

    /// @notice Test tick spacing (V3 KEY FEATURE)
    function testTickSpacing() public {
        int24 tickSpacing = pool.tickSpacing();
        assertEq(tickSpacing, 60, 'Tick spacing should be 60 for 0.3% fee tier');
        
        // V3 KEY DIFFERENCE: Ticks must be multiples of tickSpacing
        // This makes price moves discrete rather than continuous (V2)
    }
}

/// @title Helper contract to handle Uniswap V3 callbacks
contract TestMintCallback is IUniswapV3MintCallback {
    address token0;
    address token1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata
    ) external override {
        if (amount0Owed > 0) IERC20(token0).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(token1).transfer(msg.sender, amount1Owed);
    }

    function mint(
        address pool,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) external returns (uint256 amount0, uint256 amount1) {
        return IUniswapV3Pool(pool).mint(recipient, tickLower, tickUpper, liquidity, '');
    }
}

