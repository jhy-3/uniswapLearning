// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../../src/core/UniswapV2Factory.sol";
import {UniswapV2Pair} from "../../src/core/UniswapV2Pair.sol";
import {IUniswapV2Pair} from "../../src/interfaces/IUniswapV2Pair.sol";
import {ERC20} from "../mocks/ERC20.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

contract UniswapV2PairTest is Test {
    UniswapV2Factory factory;
    ERC20 token0;
    ERC20 token1;
    IUniswapV2Pair pair;
    address user = address(0x10);

    function setUp() public {
        factory = new UniswapV2Factory(address(this));
        token0 = new ERC20();
        token1 = new ERC20();
        
        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = IUniswapV2Pair(pairAddress);
        
        // Mint tokens to user
        token0.mint(user, 1000 ether);
        token1.mint(user, 1000 ether);
    }

    function testMint() public {
        uint amount0 = 100 ether;
        uint amount1 = 100 ether;
        
        vm.startPrank(user);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        uint liquidity = pair.mint(user);
        vm.stopPrank();
        
        assertGt(liquidity, 0);
        assertEq(pair.balanceOf(user), liquidity);
        
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, amount0);
        assertEq(reserve1, amount1);
    }

    function testBurn() public {
        // First mint some liquidity
        uint amount0 = 100 ether;
        uint amount1 = 100 ether;
        
        vm.startPrank(user);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        uint liquidity = pair.mint(user);
        
        // Transfer LP tokens to pair for burn
        pair.transfer(address(pair), liquidity);
        (uint amount0Out, uint amount1Out) = pair.burn(user);
        vm.stopPrank();
        
        assertGt(amount0Out, 0);
        assertGt(amount1Out, 0);
    }

    function testSwap() public {
        // First add liquidity
        uint amount0 = 100 ether;
        uint amount1 = 200 ether;
        
        vm.startPrank(user);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(user);
        
        uint balance1Before = token1.balanceOf(user);
        
        // Perform swap: use token0 to get token1
        uint amount0In = 1 ether;
        token0.transfer(address(pair), amount0In);
        pair.swap(0, 995 ether / 1000, user, ""); // ~0.995 ether out with fee
        vm.stopPrank();
        
        // User should receive token1 (balance increased)
        assertGt(token1.balanceOf(user), balance1Before);
        // User should have less token0 (spent 1 ether)
        assertLt(token0.balanceOf(user), 1000 ether);
    }
}

