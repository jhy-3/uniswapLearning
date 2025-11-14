// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../../src/core/UniswapV2Factory.sol";
import {IUniswapV2Pair} from "../../src/interfaces/IUniswapV2Pair.sol";
import {ERC20} from "../mocks/ERC20.sol";

contract UniswapV2FactoryTest is Test {
    UniswapV2Factory factory;
    ERC20 tokenA;
    ERC20 tokenB;
    address feeToSetter = address(0x1);

    function setUp() public {
        factory = new UniswapV2Factory(feeToSetter);
        tokenA = new ERC20();
        tokenB = new ERC20();
    }

    function testCreatePair() public {
        address pair = factory.createPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0));
        assertEq(factory.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factory.getPair(address(tokenB), address(tokenA)), pair);
        assertEq(factory.allPairsLength(), 1);
    }

    function testCreatePairTwiceFails() public {
        factory.createPair(address(tokenA), address(tokenB));
        vm.expectRevert("UniswapV2: PAIR_EXISTS");
        factory.createPair(address(tokenA), address(tokenB));
    }

    function testSetFeeTo() public {
        address newFeeTo = address(0x2);
        vm.prank(feeToSetter);
        factory.setFeeTo(newFeeTo);
        assertEq(factory.feeTo(), newFeeTo);
    }

    function testSetFeeToOnlySetter() public {
        address newFeeTo = address(0x2);
        vm.expectRevert("UniswapV2: FORBIDDEN");
        factory.setFeeTo(newFeeTo);
    }
}

