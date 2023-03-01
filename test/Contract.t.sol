// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "src/AMMv1.sol";
import "./helper/Setup.sol";

contract TestAMMV1 is Test, Setup {
    function setUp() public {
        assertEq(ammv1.totalTokenOne(), 0);
    }

    // function testBar() public {
    //     assertEq(uint256(1), uint256(1), "ok");
    // }

    // function testFoo(uint256 x) public {
    //     vm.assume(x < type(uint128).max);
    //     assertEq(x + x, x * 2);
    // }
}
