// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20One is ERC20, Test {
    constructor() ERC20("Token One", "TOKEN_ONE") {
        _mint(vm.addr(1), 1_000_000);
    }
}

contract MockERC20Two is ERC20, Test {
    constructor() ERC20("Token Two", "TOKEN_TWO") {
        _mint(vm.addr(1), 1_000_000);
    }
}
