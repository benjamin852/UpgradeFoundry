// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

contract AMMv1 {
    /*** STORAGE ***/

    //total shares in pool
    uint256 public totalPoolShares;

    //total tokenOne in pool
    uint256 public totalTokenOne;

    //total tokenTwo in pool
    uint256 public totalTokenTwo;

    //use to determine tokenPrice
    //k=totalToken1 * totalToken2
    uint256 public k;

    // six decimal places
    uint256 public constant PRECISION = 1_000_000;

    //share holding of each provider
    mapping(address => uint256) public shares;

    //available balance of user outside amm
    mapping(address => uint256) public tokenOneBalance;

    //balance of user outside amm
    mapping(address => uint256) public tokenTwoBalance;

    /*** ERRORS ***/
    error InvalidShares(uint256 shareOne, uint256 shareTwo);

    /*** MODIFIERS ***/

    //user must have enough balance
    modifier validAmountCheckTokenOne(uint256 _quantity) {
        require(_quantity > 0, 'validAmountCheck: amount cannot be 0');
        require(tokenOneBalance[msg.sender] > _quantity, 'validAmountCheck: Invalid token one');
        _;
    }

    //user must have enough balance
    modifier validAmountCheckTokenTwo(uint256 _quantity) {
        require(_quantity > 0, 'validAmountCheck: amount cannot be 0');
        require(tokenTwoBalance[msg.sender] > _quantity, 'validAmountCheck: Invalid token two');
        _;
    }

    //only can withdraw if liquidity added
    modifier activePool() {
        require(totalPoolShares > 0, 'activePool: Zero liquidity');
        _;
    }

    /*** FUNCTIONS ***/

    /**
     * @notice send free tokens to msg.sender
     * @param _tokenOneAmount amount of tokenOne to send
     * @param _tokenTwoAmount amount of tokenTwo to send
     */
    function faucet(uint256 _tokenOneAmount, uint256 _tokenTwoAmount) external {
        tokenOneBalance[msg.sender] = tokenOneBalance[msg.sender] + _tokenOneAmount;

        tokenTwoBalance[msg.sender] = tokenTwoBalance[msg.sender] + _tokenTwoAmount;
    }

    /**
     * Adding new liqudity to the pool
     * @param _amountTokenOne amount of tokenOne to provide
     * @param _amountTokenTwo amount of tokenTwo to provide
     * @return newShares amount of shares issued for locking assets
     */
    function provideLiquidity(
        uint256 _amountTokenOne,
        uint256 _amountTokenTwo
    )
        external
        validAmountCheckTokenOne(_amountTokenOne)
        validAmountCheckTokenTwo(_amountTokenTwo)
        returns (uint256 newShares)
    {
        //Genesis liquidity gets 100 shares
        if (totalPoolShares == 0) {
            newShares = 100 * PRECISION;
        } else {
            uint256 shareOne = (totalPoolShares * _amountTokenOne) / totalTokenOne;

            uint256 shareTwo = (totalPoolShares * _amountTokenTwo) / totalTokenTwo;

            if (shareOne != shareTwo) revert InvalidShares(shareOne, shareTwo);
            // require(shareOne == shareTwo, "AMMv1.provideLiquidity: ")
            newShares = shareOne;
        }

        require(newShares > 0, 'AMMv1.provideLiquidity: Insufficient assets provided');

        tokenOneBalance[msg.sender] -= _amountTokenOne;
        tokenTwoBalance[msg.sender] -= _amountTokenTwo;

        totalTokenOne += _amountTokenOne;
        totalTokenTwo += _amountTokenTwo;

        k = totalTokenOne * totalTokenTwo;

        totalPoolShares += newShares;
        shares[msg.sender] += newShares;
    }

    /*** HELPER FUNCTIONS ***/

    /**
     * @notice amount of tokenOne required when providing tokenTwo liquidity
     * @param _amountTokenTwo amount of tokenTwo liquidity being provided
     * @return reqTokenOne amount of tokeOne Required
     */
    function _getEquivalentToken1Estimate(
        uint256 _amountTokenTwo
    ) internal view activePool returns (uint256 reqTokenOne) {
        reqTokenOne = (totalTokenOne * _amountTokenTwo) / totalTokenTwo;
    }

    /**
     * @notice amount of tokenTwo required when providing tokenOne liquidity
     * @param _amountTokenOne amount of tokenOne liquidity being provided
     * @return reqTokenTwo amount of tokenTwo required
     */
    function _getEquivalentToken2Estimate(
        uint256 _amountTokenOne
    ) internal view activePool returns (uint256 reqTokenTwo) {
        reqTokenTwo = (totalTokenTwo * _amountTokenOne) / totalTokenOne;
    }

    /**
     * @notice Return estimate of tokens to be withdrawn when pool shares a burned
     * @param _sharesToWithdraw amount of shares to withdraw
     * @return amountTokenOne amount of token ones withdrawn
     * @return amountTokenTwo amount of token twos withdrawn
     */
    function _getWithdrawEstimate(
        uint256 _sharesToWithdraw
    ) internal view activePool returns (uint256 amountTokenOne, uint256 amountTokenTwo) {
        require(
            _sharesToWithdraw <= totalPoolShares,
            'AMMv1.getWithdrawEstimate: attempting to burn too many shares'
        );
        amountTokenOne = (_sharesToWithdraw * totalTokenOne) / totalPoolShares;
        amountTokenTwo = (_sharesToWithdraw * totalTokenTwo) / totalPoolShares;
    }
}
