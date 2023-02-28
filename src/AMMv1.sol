// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

contract AMMV1 {
    /*** STOAGE ***/

    //total shares in pool
    uint256 public totalPoolShares;

    //total tokenOne in pool
    uint256 public totalTokenOne;

    //total tokenTwo in pool
    uint256 public totalTokenTwo;

    //use to determine tokenPrice
    //k=totalToken1 * totalToken2
    uint256 public k;

    //share holding of each provider
    mapping(address => uint256) public shares;

    //available balance of user outside amm
    mapping(address => uint256) public tokenOneBalance;

    //balance of user outside amm
    mapping(address => uint256) public tokenTwoBalance;

    //user must have enough balance
    modifier validAmountCheckTokenOne(uint256 _quantity) {
        require(_quantity > 0, "validAmountCheck: amount cannot be 0");
        require(
            tokenOneBalance[msg.sender] > _quantity,
            "validAmountCheck: Invalid token one"
        );
        _;
    }

    //user must have enough balance
    modifier validAmountCheckTokenTwo(uint256 _quantity) {
        require(_quantity > 0, "validAmountCheck: amount cannot be 0");
        require(
            tokenTwoBalance[msg.sender] > _quantity,
            "validAmountCheck: Invalid token two"
        );
        _;
    }

    //only can withdraw if liquidity added
    modifier activePool() {
        require(totalPoolShares > 0, "activePool: Zero liquidity");
        _;
    }
}
