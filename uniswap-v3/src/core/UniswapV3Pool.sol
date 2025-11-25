// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '../interfaces/IUniswapV3Pool.sol';
import '../core/UniswapV3PoolDeployer.sol';
import '../libraries/TickMath.sol';
import '../libraries/SqrtPriceMath.sol';
import '../libraries/LiquidityMath.sol';
import '../libraries/Tick.sol';
import '../libraries/Position.sol';
import '../libraries/TickBitmap.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/callback/IUniswapV3MintCallback.sol';
import '../interfaces/callback/IUniswapV3FlashCallback.sol';

/// @title Uniswap V3 Pool
/// @notice KEY DIFFERENCES FROM V2:
/// 1. CONCENTRATED LIQUIDITY: Liquidity is provided within specific price ranges (tickLower to tickUpper)
///    V2: Liquidity spread across entire price range (0 to infinity)
/// 2. MULTIPLE FEE TIERS: Supports 0.05%, 0.3%, 1% fees
///    V2: Only one fee (0.3%)
/// 3. PRICE REPRESENTATION: Uses sqrtPriceX96 (Q64.96 fixed point) instead of x*y=k
///    V2: Constant product formula x * y = k
/// 4. TICK SYSTEM: Prices are tracked in discrete ticks (1.0001^tick)
///    V2: Continuous price curve
/// 5. NFT POSITIONS: Each liquidity position is an NFT (managed separately)
///    V2: LP tokens are ERC20 fungible tokens
contract UniswapV3Pool is IUniswapV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using TickBitmap for mapping(int16 => uint256);

    /// @inheritdoc IUniswapV3PoolImmutables
    address public override factory;
    address public override token0;
    address public override token1;
    uint24 public override fee;
    int24 public override tickSpacing;
    uint128 public override maxLiquidityPerTick;

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }
    /// @inheritdoc IUniswapV3PoolState
    Slot0 public override slot0;

    /// @inheritdoc IUniswapV3PoolState
    uint256 public override feeGrowthGlobal0X128;
    /// @inheritdoc IUniswapV3PoolState
    uint256 public override feeGrowthGlobal1X128;

    /// @inheritdoc IUniswapV3PoolState
    uint128 public override liquidity;

    /// @inheritdoc IUniswapV3PoolState
    mapping(int24 => Tick.Info) public override ticks;

    /// @inheritdoc IUniswapV3PoolState
    mapping(int16 => uint256) public override tickBitmap;

    /// @inheritdoc IUniswapV3PoolState
    mapping(bytes32 => Position.Info) public override positions;

    /// @dev Protocol fees
    uint128 private _protocolFee0;
    uint128 private _protocolFee1;

    /// @dev Mutually exclusive reentrancy protection into the pool to/from a method. This method also prevents entrance
    /// to a function before the pool is initialized. The reentrancy guard is required throughout the contract because
    /// we use balance checks to determine the payment status of interactions such as mint, swap and flash.
    modifier lock() {
        require(slot0.unlocked, 'LOK');
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    constructor() {
        (factory, token0, token1, fee, tickSpacing) = UniswapV3PoolDeployer(msg.sender).parameters();
        maxLiquidityPerTick = type(uint128).max; // Simplified for this implementation
    }

    /// @dev Common checks for valid tick inputs.
    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        require(tickLower < tickUpper, 'TLU');
        require(tickLower >= TickMath.MIN_TICK, 'TLM');
        require(tickUpper <= TickMath.MAX_TICK, 'TUM');
    }

    /// @inheritdoc IUniswapV3PoolActions
    function initialize(uint160 sqrtPriceX96) external override {
        require(slot0.sqrtPriceX96 == 0, 'AI');

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: 1,
            observationCardinalityNext: 1,
            feeProtocol: 0,
            unlocked: true
        });

        emit Initialize(sqrtPriceX96, tick);
    }

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    /// @dev Effect some changes to a position in a pool
    function _modifyPosition(ModifyPositionParams memory params)
        private
        returns (
            uint256 amount0,
            uint256 amount1,
            Position.Info storage position
        )
    {
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0; // SLOAD for gas optimization
        position = _updatePosition(params.owner, params.tickLower, params.tickUpper, params.liquidityDelta, _slot0.tick);
        amount0 = 0;
        amount1 = 0;

        if (params.liquidityDelta != 0) {
            uint128 absLiquidityDelta = params.liquidityDelta > 0 
                ? uint128(params.liquidityDelta) 
                : uint128(uint256(-int256(params.liquidityDelta)));
            
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ token0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    absLiquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    absLiquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    absLiquidityDelta
                );
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    absLiquidityDelta
                );
            }
        }
    }

    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        Position.update(position, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    /// @inheritdoc IUniswapV3PoolActions
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        require(amount > 0);
        (uint256 amt0, uint256 amt1, ) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int128(uint128(amount))
                })
            );

        amount0 = amt0;
        amount1 = amt1;

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        if (amount0 > 0) require(balance0Before + amount0 <= balance0(), 'M0');
        if (amount1 > 0) require(balance1Before + amount1 <= balance1(), 'M1');

        emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        (uint256 amt0, uint256 amt1, Position.Info storage position) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int128(amount)
                })
            );

        amount0 = amt0;
        amount1 = amt1;

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 - amount0,
                position.tokensOwed1 - amount1
            );

            if (amount0 > 0) IERC20(token0).transfer(recipient, amount0);
            if (amount1 > 0) IERC20(token1).transfer(recipient, amount1);
        }

        emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external override lock returns (int256 amount0, int256 amount1) {
        require(amountSpecified != 0, 'AS');

        Slot0 memory slot0Start = slot0;
        require(slot0Start.unlocked, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            'SPL'
        );

        slot0.unlocked = false;

        // Simplified swap logic - V3 KEY DIFFERENCE: price moves along ticks, not continuous curve
        // V2: x * y = k (constant product)
        // V3: price = 1.0001^tick (discrete price points)
        
        // In full implementation, this would:
        // 1. Iterate through ticks based on tickBitmap
        // 2. Calculate amount needed to cross each tick
        // 3. Update liquidity when crossing initialized ticks
        // 4. Apply fee at each step
        
        // Simplified version for demonstration:
        uint128 liquidityStart = liquidity;
        int24 tickStart = slot0Start.tick;
        uint160 sqrtPriceX96Start = slot0Start.sqrtPriceX96;

        // Calculate swap amounts (simplified)
        // V3 KEY DIFFERENCE: Swaps iterate through ticks and update liquidity
        // V2: Single constant product formula
        uint256 amountAbs = amountSpecified > 0 ? uint256(amountSpecified) : uint256(-amountSpecified);
        
        if (zeroForOne) {
            // Swap token0 for token1 (price decreases)
            uint160 sqrtPriceX96Next = SqrtPriceMath.getNextSqrtPriceFromAmount0RoundingUp(
                sqrtPriceX96Start,
                liquidityStart,
                amountAbs,
                amountSpecified > 0
            );
            slot0.sqrtPriceX96 = sqrtPriceX96Next;
            slot0.tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96Next);
            amount0 = amountSpecified;
            uint256 amount1Delta = SqrtPriceMath.getAmount1Delta(sqrtPriceX96Start, sqrtPriceX96Next, liquidityStart);
            amount1 = -int256(amount1Delta);
        } else {
            // Swap token1 for token0 (price increases)
            uint160 sqrtPriceX96Next = SqrtPriceMath.getNextSqrtPriceFromAmount1RoundingDown(
                sqrtPriceX96Start,
                liquidityStart,
                amountAbs,
                amountSpecified > 0
            );
            slot0.sqrtPriceX96 = sqrtPriceX96Next;
            slot0.tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96Next);
            uint256 amount0Delta = SqrtPriceMath.getAmount0Delta(sqrtPriceX96Start, sqrtPriceX96Next, liquidityStart);
            amount0 = -int256(amount0Delta);
            amount1 = amountSpecified;
        }

        slot0.unlocked = true;
        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, liquidity, slot0.tick);
    }

    /// @inheritdoc IUniswapV3PoolActions
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock {
        // Flash loan implementation (simplified)
        uint256 fee0 = amount0 > 0 ? (amount0 * fee) / 1000000 : 0;
        uint256 fee1 = amount1 > 0 ? (amount1 * fee) / 1000000 : 0;
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        if (amount0 > 0) IERC20(token0).transfer(recipient, amount0);
        if (amount1 > 0) IERC20(token1).transfer(recipient, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

        uint256 balance0After = balance0();
        uint256 balance1After = balance1();
        require(balance0After >= balance0Before + fee0, 'F0');
        require(balance1After >= balance1Before + fee1, 'F1');

        emit Flash(msg.sender, recipient, amount0, amount1, fee0, fee1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external override lock {
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
        uint16 observationCardinalityNextNew =
            observationCardinalityNextOld > observationCardinalityNext ? observationCardinalityNextOld : observationCardinalityNext;
        slot0.observationCardinalityNext = observationCardinalityNextNew;
        if (observationCardinalityNextOld != observationCardinalityNextNew) {
            // emit event if needed
        }
    }

    /// @inheritdoc IUniswapV3PoolDerivedState
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        // Simplified oracle implementation
        return (new int56[](secondsAgos.length), new uint160[](secondsAgos.length));
    }

    /// @inheritdoc IUniswapV3PoolDerivedState
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        override
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        )
    {
        // Simplified implementation
        return (0, 0, 0);
    }

    /// @inheritdoc IUniswapV3PoolState
    function observations(uint256 index)
        external
        view
        override
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        )
    {
        // Simplified implementation - return empty observation
        return (0, 0, 0, false);
    }

    /// @inheritdoc IUniswapV3PoolOwnerActions
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override lock {
        require(msg.sender == factory);
        uint8 feeProtocolOld = slot0.feeProtocol;
        slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
        emit SetFeeProtocol(
            feeProtocolOld % 16,
            feeProtocolOld >> 4,
            feeProtocol0,
            feeProtocol1
        );
    }

    /// @inheritdoc IUniswapV3PoolOwnerActions
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        require(msg.sender == factory);
        amount0 = amount0Requested > _protocolFee0 ? _protocolFee0 : amount0Requested;
        amount1 = amount1Requested > _protocolFee1 ? _protocolFee1 : amount1Requested;

        if (amount0 > 0 || amount1 > 0) {
            if (amount0 > 0) {
                _protocolFee0 -= amount0;
                IERC20(token0).transfer(recipient, amount0);
            }
            if (amount1 > 0) {
                _protocolFee1 -= amount1;
                IERC20(token1).transfer(recipient, amount1);
            }
        }
        emit CollectProtocol(msg.sender, recipient, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolState
    function protocolFees() external view override returns (uint128 fee0, uint128 fee1) {
        fee0 = _protocolFee0;
        fee1 = _protocolFee1;
    }

    function balance0() private view returns (uint256) {
        return IERC20(token0).balanceOf(address(this));
    }

    function balance1() private view returns (uint256) {
        return IERC20(token1).balanceOf(address(this));
    }
}

