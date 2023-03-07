// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import 'openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

contract AMMv1 is Initializable {
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
        require(totalPoolShares > 0, 'ammv1: Zero liquidity');
        _;
    }

    /***************
        FUNCTIONS 
     ***************/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*** LIQUIDITY ***/

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

    /*** WITHDRAW ***/

    /**
     * @notice withdraw liquidity from pool and return tokenOne & tokenTwo to withdrawer
     * @param _shares amount of shares to withdaw
     * @return tokenOneAmount amount of tokenOne to receive
     * @return tokenTwoAmount amount of tokenTwo to receive
     */
    function withdraw(
        uint256 _shares
    )
        external
        activePool
        returns (
            //   validAmountCheckTokenOne(_shares)
            //   validAmountCheckTokenTwo(_shares)
            uint256 tokenOneAmount,
            uint256 tokenTwoAmount
        )
    {
        (uint256 withdrawAmountTokenOne, uint256 withdrawAmountTokenTwo) = _getWithdrawEstimate(
            _shares
        );

        // subtract total shares from provider
        shares[msg.sender] -= _shares;

        // subtract total shares
        totalPoolShares -= _shares;

        // subtract totalTokenOne from pool
        totalTokenOne -= withdrawAmountTokenOne;

        // subtract totalTokenTwo from pool
        totalTokenTwo -= withdrawAmountTokenTwo;

        k = totalTokenOne * totalTokenTwo;

        // increment withdrawer tokenOne balance
        tokenOneBalance[msg.sender] += withdrawAmountTokenOne;

        // increment withdraw tokenTwo balance
        tokenTwoBalance[msg.sender] += withdrawAmountTokenTwo;
    }

    /*** SWAP ***/

    /**
     * @notice swap tokenOne in return for tokenTwo
     * @param _amountTokenOne amount of tokenOne to swap in
     * @return amountTokenTwo amount of tokenTwo we get in return
     */
    function swapTokenOne(
        uint256 _amountTokenOne
    )
        external
        activePool
        validAmountCheckTokenOne(_amountTokenOne)
        returns (uint256 amountTokenTwo)
    {
        amountTokenTwo = _getSwapTokenOneEstimate(_amountTokenOne);
        tokenOneBalance[msg.sender] -= _amountTokenOne;
        totalTokenOne += _amountTokenOne;
        totalTokenTwo -= amountTokenTwo;

        tokenTwoBalance[msg.sender] += amountTokenTwo;
    }

    /**
     * @notice Swap tokenTwo for tokenOne
     * @param _amountTokenTwo amount of tokenTwo to swap in
     * @return amountTokenOne amount of tokenOne to get in return
     */
    function swapTokenTwo(
        uint256 _amountTokenTwo
    )
        external
        activePool
        validAmountCheckTokenTwo(_amountTokenTwo)
        returns (uint256 amountTokenOne)
    {
        amountTokenOne = _getSwapTokenTwoEstimate(_amountTokenTwo);

        tokenTwoBalance[msg.sender] -= _amountTokenTwo;
        totalTokenTwo += _amountTokenTwo;
        totalTokenOne -= amountTokenOne;

        tokenOneBalance[msg.sender] += amountTokenOne;
    }

    /**** GETTER ****/

    /**
     * @notice amount of tokenOne needed to swap to receive a certain amount of tokenOne
     * @param _amountTokenTwo amount of token two to swap
     * @return amountTokenOne amount of token one returned
     */
    function getSwapReceiveTokenOneEstimate(
        uint256 _amountTokenTwo
    ) external view activePool returns (uint256 amountTokenOne) {
        require(
            _amountTokenTwo < totalTokenTwo,
            'AMMv1.getSwapReceiveTokenOneEstimate: Insufficient pool banace'
        );
        uint256 tokenTwoAfter = totalTokenTwo - _amountTokenTwo;
        uint256 relativeTokenOneAfter = k / tokenTwoAfter;
        amountTokenOne = relativeTokenOneAfter - totalTokenOne;
    }

    /**
     * @notice amount of tokenTwo needed to swap to receive a certain amount of tokenOne
     * @param _amountTokenOne amount of tokenOne to swap
     * @return amountTokenTwo amount of tokenTwo returned
     */
    function getSwapReceiveTokenTwoEstimate(
        uint256 _amountTokenOne
    ) external view activePool returns (uint256 amountTokenTwo) {
        require(
            _amountTokenOne < totalTokenOne,
            'ammv1.getSwapReceiveTokenTwoEstimate: insufficient pool balance'
        );
        uint256 tokenOneAfter = totalTokenOne - _amountTokenOne;
        uint256 relativeTokenTwoAfter = k / tokenOneAfter;

        amountTokenTwo = relativeTokenTwoAfter - totalTokenOne;
    }

    function iamV2() public pure returns (bool) {
        return true;
    }

    /***************
        HELPER 
     ***************/
    /**
     * @notice amount of tokenOne required when providing tokenTwo liquidity
     * @param _amountTokenTwo amount of tokenTwo liquidity being provided
     * @return reqTokenOne amount of tokeOne Required
     */
    function _getEquivalentToken1Estimate(
        uint256 _amountTokenTwo
    ) internal view returns (uint256 reqTokenOne) {
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
     * @return withdrawAmountTokenOne amount of token ones withdrawn
     * @return withdrawAmountTokenTwo amount of token twos withdrawn
     */
    function _getWithdrawEstimate(
        uint256 _sharesToWithdraw
    )
        internal
        view
        activePool
        returns (uint256 withdrawAmountTokenOne, uint256 withdrawAmountTokenTwo)
    {
        require(
            _sharesToWithdraw <= totalPoolShares,
            'AMMv1.getWithdrawEstimate: attempting to burn too many shares'
        );
        withdrawAmountTokenOne = (_sharesToWithdraw * totalTokenOne) / totalPoolShares;
        withdrawAmountTokenTwo = (_sharesToWithdraw * totalTokenTwo) / totalPoolShares;
    }

    /**
     * @notice Get amount of tokenTwo user receives when swapping tokenOne
     * @param _amountTokenOne amount of tokenOne being swapped in
     * @return amountTokenTwo amount of tokenTwo being returned
     */
    function _getSwapTokenOneEstimate(
        uint256 _amountTokenOne
    ) internal view returns (uint256 amountTokenTwo) {
        //add new tokenOne to total pool balance of tokenOne
        uint256 tokenOneAfter = totalTokenOne + _amountTokenOne;

        //caclculate howmany tokens will remain in pool after swap
        uint256 tokenTwoAfter = k / tokenOneAfter;

        //return correct amount to swapper
        amountTokenTwo = totalTokenTwo - tokenTwoAfter;

        // revert the pool if we hit 0 assetTwo in the pool
        if (amountTokenTwo == totalTokenTwo) amountTokenTwo--;
    }

    /**
     * @notice Get amount of tokenOne user wil receive when swapping tokenTwo
     * @param _amountTokenTwo amount of tokenTwo swapping away
     * @return amountTokenOne amount of tokenOne received
     */
    function _getSwapTokenTwoEstimate(
        uint256 _amountTokenTwo
    ) internal view activePool returns (uint256 amountTokenOne) {
        uint256 tokenTwoAfter = totalTokenTwo + _amountTokenTwo;
        uint256 tokenOneAfter = k / tokenTwoAfter;

        amountTokenOne = totalTokenOne - tokenOneAfter;

        //Ensure tokenOne's pool is not empty
        if (amountTokenOne == totalTokenOne) amountTokenOne--;
    }
}
