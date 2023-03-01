// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/AMMv1.sol";

contract Setup is Test {
    AMMv1 public ammv1;

    constructor() {
        ammv1 = new AMMv1();
    }
}
