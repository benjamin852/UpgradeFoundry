// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import 'forge-std/Test.sol';

import 'src/AMMv1.sol';
import 'src/AMMv2.sol';

import './helper/Setup.sol';
import 'openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import 'openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol';

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
    uint256 public poolShares;

    function setUp() public {
        vm.prank(vm.addr(1));
        ammv1.faucet(10 ether, 10 ether);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(7 ether, 7 ether);
        poolShares = ammv1.totalPoolShares();
    }

    // should revert if withdrawing invalid shares
    function testRevertInvalidSharesToWithdraw() public {
        vm.expectRevert('AMMv1.getWithdrawEstimate: attempting to burn too many shares');
        ammv1.withdraw(100_000_001);
    }

    //reduce users shares
    function testShouldReduceUsersShares() public {
        uint256 sharesBefore = ammv1.shares(vm.addr(1));
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 sharesAfter = ammv1.shares(vm.addr(1));
        assertEq(sharesAfter, sharesBefore - 50);
    }

    //reduce total pool shares
    function testShouldReduceTotalPoolShares() public {
        uint256 sharesBefore = ammv1.totalPoolShares();
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 sharesAfter = ammv1.totalPoolShares();
        assertEq(sharesAfter, sharesBefore - 50);
    }

    //reduce correct tokenOne from pool
    function testShouldReduceTotalTokenOneFromPool() public {
        uint256 totalTokenOneBefore = ammv1.totalTokenOne();
        uint256 expectedDifference = (50 * totalTokenOneBefore) / poolShares;
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 totalTokenOneAfter = ammv1.totalTokenOne();
        assertEq(totalTokenOneAfter, totalTokenOneBefore - expectedDifference);
    }

    //reduce correct tokenTwo from pool
    function testShouldReduceTotalTokenTwoFromPool() public {
        uint256 totalTokenTwoBefore = ammv1.totalTokenTwo();
        uint256 expectedDifference = (50 * totalTokenTwoBefore) / poolShares;
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 totalTokenTwoAfter = ammv1.totalTokenTwo();
        assertEq(totalTokenTwoAfter, totalTokenTwoBefore - expectedDifference);
    }

    //should set correct k amount
    function testShouldSetCorrectKAmount() public {
        uint256 expectedTokenOneBefore = ammv1.totalTokenOne();
        uint256 expectedTokenTwoBefore = ammv1.totalTokenTwo();
        uint256 expectedKBefore = expectedTokenOneBefore * expectedTokenTwoBefore;
        uint256 kBefore = ammv1.k();
        assertEq(kBefore, expectedKBefore);
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 expectedTokenOne = ammv1.totalTokenOne();
        uint256 expectedTokenTwo = ammv1.totalTokenTwo();
        uint256 expectedK = expectedTokenOne * expectedTokenTwo;
        uint256 kAfter = ammv1.k();
        assertEq(kAfter, expectedK);
        assertGt(kBefore, kAfter);
    }

    //should increase user's token one balance after withdraw
    function testIncreaseUserTokenOneBalance() public {
        uint256 userTokenBalanceBefore = ammv1.tokenOneBalance(vm.addr(1));
        uint256 totalTokenOne = ammv1.totalTokenOne();
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 userTokenBalanceAfter = ammv1.tokenOneBalance(vm.addr(1));

        uint256 expectedDifference = (50 * totalTokenOne) / poolShares;

        assertEq(userTokenBalanceAfter, userTokenBalanceBefore + expectedDifference);
    }

    //should increase user's token two balance after withdraw
    function testIncreaseUserTokenTwoBalance() public {
        uint256 userTokenBalanceBefore = ammv1.tokenTwoBalance(vm.addr(1));
        uint256 totalTokenTwo = ammv1.totalTokenTwo();
        vm.prank(vm.addr(1));
        ammv1.withdraw(50);
        uint256 userTokenBalanceAfter = ammv1.tokenTwoBalance(vm.addr(1));

        uint256 expectedDifference = (50 * totalTokenTwo) / poolShares;

        assertEq(userTokenBalanceAfter, userTokenBalanceBefore + expectedDifference);
    }
}

contract Swap is Test, Setup {
    function setUp() public {
        vm.prank(vm.addr(1));
        ammv1.faucet(10 ether, 10 ether);
        vm.prank(vm.addr(1));
        ammv1.provideLiquidity(7 ether, 7 ether);
    }

    // should decrement user tokenOne supply
    function testDeductTokenOneFromSender() public {
        uint256 totalTokensBefore = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(totalTokensBefore, 10 ether - 7 ether);
        vm.prank(vm.addr(1));
        ammv1.swapTokenOne(1 ether);
        uint256 totalTokensAfter = ammv1.tokenOneBalance(vm.addr(1));
        assertEq(totalTokensAfter, totalTokensBefore - 1 ether);
    }

    // should increment dex tokenOne supply
    function testIncrementTokenOneToDex() public {
        uint256 dexBalanceBefore = ammv1.totalTokenOne();
        assertEq(dexBalanceBefore, 7 ether);
        vm.prank(vm.addr(1));
        ammv1.swapTokenOne(1 ether);
        uint256 dexBalanceAfter = ammv1.totalTokenOne();
        assertEq(dexBalanceAfter, 7 ether + 1 ether);
    }

    // should decrement dex tokenTwo supply
    function testDecrementDokenTwoFromDex() public {
        uint256 dexBalanceBefore = ammv1.totalTokenTwo();
        assertEq(dexBalanceBefore, 7 ether);
        vm.prank(vm.addr(1));
        ammv1.swapTokenOne(1 ether);

        uint256 dexBalanceAfter = ammv1.totalTokenTwo();

        uint256 k = ammv1.k();
        uint256 expectedDexBalance = k / (dexBalanceBefore + 1 ether);

        assertEq(dexBalanceAfter, expectedDexBalance);

        // additional test option
        // (amountTokenTwo) = _getSwapTokenOneEstimate(_amountTokenOne);
        // assetEq(dexBalanceAfter, dexBalanceBefore - amountTokenTwo);
    }

    // should increment sender tokenTwo supply
    function testShouldIncrementSenderTokenTwo() public {
        uint256 dexBalanceBefore = ammv1.totalTokenTwo();
        uint256 totalTokensBefore = ammv1.tokenTwoBalance(vm.addr(1));

        assertEq(totalTokensBefore, 10 ether - 7 ether);
        vm.prank(vm.addr(1));
        ammv1.swapTokenOne(1 ether);
        uint256 totalTokensAfter = ammv1.tokenTwoBalance(vm.addr(1));

        uint256 k = ammv1.k();
        uint256 expectedDexBalance = k / (dexBalanceBefore + 1 ether);
        uint256 expectedTokenTwoPayout = dexBalanceBefore - expectedDexBalance;

        assertEq(totalTokensAfter, totalTokensBefore + expectedTokenTwoPayout);
    }
}

contract Upgradeability is Test, Setup {
    ProxyAdmin public admin;
    TransparentUpgradeableProxy public proxy;
    AMMv1 public ammV1Implementation;
    AMMv2 public ammv2Implementation;
    AMMv1 public wrappedProxyV1;
    AMMv2 public wrappedProxyV2;

    function setUp() public {
        admin = new ProxyAdmin();

        // get implementation v1
        ammV1Implementation = new AMMv1();

        // get implementation v2
        ammv2Implementation = new AMMv2();

        // deploy proxy
        proxy = new TransparentUpgradeableProxy(address(ammV1Implementation), address(admin), '');

        // wrap ABI in proxy to make interactions with proxy simpler
        wrappedProxyV1 = AMMv1(address(proxy));

        //if there was an init
        // wrappedProxyV1.initialize(123)
    }

    function testUpgradesToV2() public {
        //upgrade proxy
        admin.upgrade(proxy, address(ammv2Implementation));

        //wrap proxy with new abi
        wrappedProxyV2 = AMMv2(address(proxy));

        assertEq(address(wrappedProxyV2), address(wrappedProxyV1));

        assertTrue(wrappedProxyV2.iamV2());
    }
}
