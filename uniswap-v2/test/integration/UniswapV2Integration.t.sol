// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../../src/core/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../../src/periphery/UniswapV2Router02.sol";
import {IUniswapV2Pair} from "../../src/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "../../src/interfaces/IUniswapV2Router02.sol";
import {ERC20} from "../mocks/ERC20.sol";
import {WETH} from "../mocks/WETH.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

contract UniswapV2IntegrationTest is Test {
    UniswapV2Factory factory;
    UniswapV2Router02 router;
    WETH weth;
    ERC20 tokenA;
    ERC20 tokenB;
    
    address user1;
    address user2;
    address feeToSetter = address(this);
    
    uint constant INITIAL_BALANCE = 10000 ether;
    uint constant LIQUIDITY_AMOUNT = 1000 ether;

    function setUp() public {
        // Create user addresses that can receive ETH
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy factory
        factory = new UniswapV2Factory(feeToSetter);
        
        // Deploy WETH
        weth = new WETH();
        
        // Deploy router
        router = new UniswapV2Router02(address(factory), address(weth));
        
        // Deploy test tokens
        tokenA = new ERC20();
        tokenB = new ERC20();
        
        // Mint tokens to users
        tokenA.mint(user1, INITIAL_BALANCE);
        tokenB.mint(user1, INITIAL_BALANCE);
        tokenA.mint(user2, INITIAL_BALANCE);
        tokenB.mint(user2, INITIAL_BALANCE);
        
        // Give ETH to users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // ========== 测试添加流动性 (LP 加入) ==========
    
    function testAddLiquidity() public {
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        (uint amountAUsed, uint amountBUsed, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0, // amountAMin
            0, // amountBMin
            user1,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertGt(liquidity, 0, "Liquidity should be greater than 0");
        assertEq(amountAUsed, amountA, "All tokenA should be used");
        assertEq(amountBUsed, amountB, "All tokenB should be used");
        
        // 验证 LP Token 余额
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(user1), liquidity, "User should receive LP tokens");
        
        // 验证储备量
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(uint256(reserve0) + uint256(reserve1), amountA + amountB, "Reserves should match");
    }

    function testAddLiquidityETH() public {
        uint amountToken = LIQUIDITY_AMOUNT;
        uint amountETH = 10 ether;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountToken);
        
        (uint amountTokenUsed, uint amountETHUsed, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            0, // amountTokenMin
            0, // amountETHMin
            user1,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertGt(liquidity, 0, "Liquidity should be greater than 0");
        assertGt(amountTokenUsed, 0, "Token should be used");
        assertGt(amountETHUsed, 0, "ETH should be used");
        
        // 验证 WETH 余额
        assertGt(weth.balanceOf(address(factory.getPair(address(tokenA), address(weth)))), 0);
    }

    // ========== 测试移除流动性 (LP 退出) ==========
    
    function testRemoveLiquidity() public {
        // 先添加流动性
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        
        // 移除流动性
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        pair.approve(address(router), liquidity);
        
        uint balanceA0 = tokenA.balanceOf(user1);
        uint balanceB0 = tokenB.balanceOf(user1);
        
        (uint amountAOut, uint amountBOut) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0, // amountAMin
            0, // amountBMin
            user1,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证返回的代币数量
        assertGt(amountAOut, 0, "Should return tokenA");
        assertGt(amountBOut, 0, "Should return tokenB");
        
        // 验证用户余额增加
        assertEq(tokenA.balanceOf(user1), balanceA0 + amountAOut);
        assertEq(tokenB.balanceOf(user1), balanceB0 + amountBOut);
        
        // 验证 LP Token 被销毁
        assertEq(pair.balanceOf(user1), 0, "LP tokens should be burned");
    }

    function testRemoveLiquidityETH() public {
        // 先添加 ETH 流动性
        uint amountToken = LIQUIDITY_AMOUNT;
        uint amountETH = 10 ether;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountToken);
        
        (,, uint liquidity) = router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        
        // 移除流动性
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        pair.approve(address(router), liquidity);
        
        uint ethBalance0 = user1.balance;
        uint tokenBalance0 = tokenA.balanceOf(user1);
        
        (uint amountTokenOut, uint amountETHOut) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0, // amountTokenMin
            0, // amountETHMin
            user1,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertGt(amountTokenOut, 0, "Should return tokens");
        assertGt(amountETHOut, 0, "Should return ETH");
        assertEq(user1.balance, ethBalance0 + amountETHOut, "ETH should be returned");
        assertEq(tokenA.balanceOf(user1), tokenBalance0 + amountTokenOut, "Tokens should be returned");
    }

    // ========== 测试代币交换 (买卖代币) ==========
    
    function testSwapExactTokensForTokens() public {
        // 先添加流动性
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 用户2交换代币
        uint amountIn = 100 ether;
        uint balanceB0 = tokenB.balanceOf(user2);
        
        vm.startPrank(user2);
        tokenA.approve(address(router), amountIn);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0, // amountOutMin
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertEq(amounts[0], amountIn, "Input amount should match");
        assertGt(amounts[1], 0, "Should get output tokens");
        assertLt(amounts[1], amountIn, "Output should be less than input (fee + price impact)");
        
        // 验证用户2收到了 tokenB
        assertEq(tokenB.balanceOf(user2), balanceB0 + amounts[1], "User2 should receive tokenB");
        assertEq(tokenA.balanceOf(user2), INITIAL_BALANCE - amountIn, "User2 should spend tokenA");
    }

    function testSwapTokensForExactTokens() public {
        // 先添加流动性
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 用户2用精确的 tokenA 换取精确的 tokenB
        uint amountOut = 50 ether;
        uint balanceA0 = tokenA.balanceOf(user2);
        
        vm.startPrank(user2);
        tokenA.approve(address(router), type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.swapTokensForExactTokens(
            amountOut,
            type(uint256).max, // amountInMax
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertEq(amounts[amounts.length - 1], amountOut, "Output amount should match");
        assertGt(amounts[0], amountOut, "Input should be more than output");
        assertEq(tokenB.balanceOf(user2), INITIAL_BALANCE + amountOut, "Should get exact output");
        assertEq(tokenA.balanceOf(user2), balanceA0 - amounts[0], "Should spend calculated input");
    }

    function testSwapExactETHForTokens() public {
        // 先添加流动性
        uint amountToken = LIQUIDITY_AMOUNT;
        uint amountETH = 10 ether;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountToken);
        
        router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 用户2用 ETH 购买代币
        uint ethAmount = 1 ether;
        uint tokenBalance0 = tokenA.balanceOf(user2);
        
        vm.startPrank(user2);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        uint[] memory amounts = router.swapExactETHForTokens{value: ethAmount}(
            0, // amountOutMin
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertEq(amounts[0], ethAmount, "ETH input should match");
        assertGt(amounts[1], 0, "Should get tokens");
        assertEq(tokenA.balanceOf(user2), tokenBalance0 + amounts[1], "Should receive tokens");
        assertEq(user2.balance, 100 ether - ethAmount, "Should spend ETH");
    }

    function testSwapTokensForExactETH() public {
        // 先添加流动性
        uint amountToken = LIQUIDITY_AMOUNT;
        uint amountETH = 10 ether;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountToken);
        
        router.addLiquidityETH{value: amountETH}(
            address(tokenA),
            amountToken,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 用户2用代币换取精确的 ETH
        uint ethAmountOut = 0.5 ether;
        uint tokenBalance0 = tokenA.balanceOf(user2);
        uint ethBalance0 = user2.balance;
        
        vm.startPrank(user2);
        tokenA.approve(address(router), type(uint256).max);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        uint[] memory amounts = router.swapTokensForExactETH(
            ethAmountOut,
            type(uint256).max, // amountInMax
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertEq(amounts[amounts.length - 1], ethAmountOut, "ETH output should match");
        assertGt(amounts[0], 0, "Should spend tokens");
        assertEq(user2.balance, ethBalance0 + ethAmountOut, "Should receive ETH");
        assertEq(tokenA.balanceOf(user2), tokenBalance0 - amounts[0], "Should spend tokens");
    }

    // ========== 测试多跳路径交换 ==========
    
    function testMultiHopSwap() public {
        // 创建三个代币的流动性池
        ERC20 tokenC = new ERC20();
        tokenC.mint(user1, INITIAL_BALANCE);
        tokenC.mint(user2, INITIAL_BALANCE);
        
        vm.startPrank(user1);
        // A-B 池
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        
        // B-C 池
        tokenC.approve(address(router), type(uint256).max);
        router.addLiquidity(
            address(tokenB),
            address(tokenC),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 用户2通过 A -> B -> C 路径交换
        uint amountIn = 100 ether;
        
        vm.startPrank(user2);
        tokenA.approve(address(router), amountIn);
        
        address[] memory path = new address[](3);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
        
        // 验证结果
        assertEq(amounts[0], amountIn, "First input should match");
        assertGt(amounts[1], 0, "Intermediate amount should exist");
        assertGt(amounts[2], 0, "Final output should exist");
        assertLt(amounts[2], amountIn, "Output should be less (fees in two pools)");
    }

    // ========== 测试滑点保护 ==========
    
    function testSlippageProtection() public {
        // 先添加流动性
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 尝试交换，但要求过高的输出（应该失败）
        vm.startPrank(user2);
        tokenA.approve(address(router), 100 ether);
        
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        router.swapExactTokensForTokens(
            100 ether,
            200 ether, // 要求过高的输出
            path,
            user2,
            block.timestamp + 1000
        );
        
        vm.stopPrank();
    }

    // ========== 测试价格计算 ==========
    
    function testGetAmountsOut() public {
        // 先添加流动性
        uint amountA = LIQUIDITY_AMOUNT;
        uint amountB = LIQUIDITY_AMOUNT;
        
        vm.startPrank(user1);
        tokenA.approve(address(router), amountA);
        tokenB.approve(address(router), amountB);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            amountA,
            amountB,
            0,
            0,
            user1,
            block.timestamp + 1000
        );
        vm.stopPrank();
        
        // 查询价格
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        uint[] memory amounts = router.getAmountsOut(100 ether, path);
        
        // 验证结果
        assertEq(amounts[0], 100 ether, "Input should match");
        assertGt(amounts[1], 0, "Should calculate output");
        assertLt(amounts[1], 100 ether, "Output should be less due to fee");
    }
}

