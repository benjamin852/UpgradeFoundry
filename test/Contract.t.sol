// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';

import 'src/AMMv1.sol';

// import "./helper/Setup.sol";

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
        vm.expectRevert('validAmountCheck: amount cannot be 0');
        ammv1.provideLiquidity(0, 10);
    }

    function testRevertIfNoLiquidityTokenTwo() public {
        vm.expectRevert('validAmountCheck: amount cannot be 0');
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

contract ProvideLiquidity is Test, Setup {
    uint256 public initialBalance = 10_000;
    uint256 public liquidityAmount = 10;

    function setUp() public {
        vm.prank(vm.addr(1));
        ammv1.faucet(initialBalance, initialBalance);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount);
    }

    function testShouldRevertIfSharesDoNotMatch() public {
        // TODO figure out how to revert error message of custom error
        vm.expectRevert();
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount - 1);
    }

    function testDecreaseTokenOneUserBalance() public {
        uint256 tokenOneBalanceBefore = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(tokenOneBalanceBefore, initialBalance - liquidityAmount);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(100, 100);
        uint256 tokenOneBalanceAfter = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(tokenOneBalanceAfter, tokenOneBalanceBefore - 100);
    }

    function testDecreaseTokenTwoUserBalance() public {
        uint256 tokenTwoBalanceBefore = ammv1.tokenTwoBalance(vm.addr(1));
        assertEq(tokenTwoBalanceBefore, initialBalance - liquidityAmount);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(100, 100);
        uint256 tokenTwoBalanceAfter = ammv1.tokenTwoBalance(vm.addr(1));
        assertEq(tokenTwoBalanceAfter, tokenTwoBalanceBefore - 100);
    }

    function testIncreaseTotalTokenOneAmmBalance() public {
        uint256 tokenOneBalanceBefore = ammv1.totalTokenOne();
        assertEq(tokenOneBalanceBefore, liquidityAmount);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount);
        uint256 tokenOneBalanceAfter = ammv1.totalTokenOne();
        assertEq(tokenOneBalanceAfter, liquidityAmount * 2);
    }

    function testIncreaseTotalTokenTwoAmmBalance() public {
        uint256 tokenTwoBalanceBefore = ammv1.totalTokenTwo();
        assertEq(tokenTwoBalanceBefore, liquidityAmount);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount);
        uint256 tokenTwoBalanceAfter = ammv1.totalTokenTwo();
        assertEq(tokenTwoBalanceAfter, liquidityAmount * 2);
    }

    function testSetCorrectKAmount() public {
        uint256 kBalanceBefore = ammv1.k();
        assertEq(kBalanceBefore, (liquidityAmount * liquidityAmount));
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount);
        uint256 kBalanceAfter = ammv1.k();
        uint256 totalTokenOneAfter = ammv1.totalTokenOne();
        uint256 totalTokenTwoAfter = ammv1.totalTokenTwo();
        assertEq(kBalanceAfter, totalTokenOneAfter * totalTokenTwoAfter);
    }

    function testIncreaseTotalPoolShares() public {
        uint256 totalPoolSharesBefore = ammv1.totalPoolShares();
        uint256 precision = ammv1.PRECISION();
        assertEq(totalPoolSharesBefore, 100 * precision);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(liquidityAmount, liquidityAmount);
        uint256 totalPoolSharesAfter = ammv1.totalPoolShares();
        assertEq(totalPoolSharesAfter, totalPoolSharesBefore * 2);
    }
}

contract Withdraw is Test, Setup {
    //dont forget withdrawEstimate
    // test each line in withdraw
}
