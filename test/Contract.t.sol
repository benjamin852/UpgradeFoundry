// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/AMMv1.sol";
import "./helper/Setup.sol";

contract Initialization is Test, Setup {
    function setUp() public {
        assertEq(ammv1.totalPoolShares(), 0);
        assertEq(ammv1.totalTokenOne(), 0);
        assertEq(ammv1.totalTokenTwo(), 0);
        assertEq(ammv1.k(), 0);
    }
}

contract Faucet is Test, Setup {
    function testIncreaseTokenOneBalance() public {
        uint256 tokenOneBalanceBefore = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(tokenOneBalanceBefore, 0);
        vm.prank(vm.addr(1));
        ammv1.faucet(10, 0);
        uint256 tokenOneBalanceAfter = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(tokenOneBalanceAfter, 10);
    }

    function testIncreaseTokenTwoBalance() public {
        uint256 tokenTwoBalanceBefore = ammv1.tokenTwoBalance(vm.addr(1));
        assertEq(tokenTwoBalanceBefore, 0);
        vm.prank(vm.addr(1));
        ammv1.faucet(0, 10);
        uint256 tokenTwoBalanceAfter = ammv1.tokenTwoBalance(vm.addr(1));
        assertEq(tokenTwoBalanceAfter, 10);
    }
}

contract ProvideLiquidityFirstTime is Test, Setup {
    function setUp() public {
        ammv1.faucet(10_000, 10_000);
    }

    function testRevertIfNoLiquidityTokenOne() public {
        vm.expectRevert("validAmountCheck: amount cannot be 0");
        ammv1.provideLiquidity(0, 10);
    }

    function testRevertIfNoLiquidityTokenTwo() public {
        vm.expectRevert("validAmountCheck: amount cannot be 0");
        ammv1.provideLiquidity(10, 0);
    }

    function testNewPool100Shares() public {
        uint256 totalPoolSharesBefore = ammv1.totalPoolShares();
        assertEq(totalPoolSharesBefore, 0);
        ammv1.provideLiquidity(10, 10);
        uint256 totalPoolSharesAfter = ammv1.totalPoolShares();
        assertEq(totalPoolSharesAfter, 100 * 1_000_000);
    }
}
