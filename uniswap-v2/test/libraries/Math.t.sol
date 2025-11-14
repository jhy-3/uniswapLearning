// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";
import {Math} from "../../src/libraries/Math.sol";

contract MathTest is Test {
    function testMin() public {
        assertEq(Math.min(1, 2), 1);
        assertEq(Math.min(2, 1), 1);
        assertEq(Math.min(100, 100), 100);
        assertEq(Math.min(0, 1), 0);
    }

    function testSqrt() public {
        assertEq(Math.sqrt(0), 0);
        assertEq(Math.sqrt(1), 1);
        assertEq(Math.sqrt(4), 2);
        assertEq(Math.sqrt(9), 3);
        assertEq(Math.sqrt(16), 4);
        assertEq(Math.sqrt(100), 10);
        assertEq(Math.sqrt(10000), 100);
    }

    function testSqrtLargeNumbers() public {
        assertEq(Math.sqrt(100000000), 10000);
        assertEq(Math.sqrt(10000000000), 100000);
    }
}

