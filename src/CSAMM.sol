// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "./IERC20.sol";

contract CSAMM {

    ////////////////////////////////////////////////////
    ///////// Errors ///////////////////////////////////
    ////////////////////////////////////////////////////

    error CSAMM__NotValidToken();
    error CSAMM__ZeroAddress();
    error CSAMM__ZeroAmountNotAllowed();
    error CSAMM__NullSharesMinted();
    error CSAMM__DidNotDepositLiquidity();

    ////////////////////////////////////////////////////
    /////////  Events //////////////////////////////////
    ////////////////////////////////////////////////////

    event LiquidityAdded(address indexed sender,uint256 indexed shares,uint256 amountToken0Added, uint256 amountToken1Added);
    event LiquidityRemoved(address indexed sender, uint256 indexed amountToken0Out, uint256 indexed amountToken1Out);
    event SwapToken(address sender, address indexed token, uint256 indexed amountReturned, uint256 indexed amountDepositedTowap);

    ////////////////////////////////////////////////////
    ///////// State Variables //////////////////////////
    ////////////////////////////////////////////////////

    IERC20 private immutable i_token0;
    IERC20 private immutable i_token1;

    uint256 private s_reserve0;
    uint256 private s_reserve1;

    uint256 private s_totalSupply;
    mapping(address owner => uint256 shares) private s_balanceOf;

    constructor(address _token0, address _token1) payable {
        i_token0 = IERC20(_token0);
        i_token1 = IERC20(_token1);
    }

    ////////////////////////////////////////////////////
    ///////// Internal Functions ///////////////////////
    ////////////////////////////////////////////////////

    function _mint(address _to, uint256 _amount) internal {
        unchecked {
            s_balanceOf[_to] += _amount;
            s_totalSupply += _amount;
        }
    }

    function _burn(address _from, uint256 _amount) internal {
        unchecked {
            s_balanceOf[_from] -= _amount;
            s_totalSupply -= _amount;
        }
    }

    function _update(uint256 _res0, uint256 _res1) internal {
        s_reserve0 = _res0;
        s_reserve1 = _res1;
    }

    ////////////////////////////////////////////////////
    ///////// External Functions ///////////////////////
    ////////////////////////////////////////////////////

    function swap(address _tokenIn, uint256 _amountIn) external returns (uint256 _amountOut) {
        if (_amountIn == 0) {
            revert CSAMM__ZeroAmountNotAllowed();
        }

        if (_tokenIn == address(0)) {
            revert CSAMM__ZeroAddress();
        }
        
        if (_tokenIn != getToken0() || _tokenIn != getToken1()) {
            revert CSAMM__NotValidToken();
        }

        // require(_tokenIn == getToken0() || _tokenIn == getToken1());
        
        uint256 amountIn; 

        if (_tokenIn == address(i_token0)) {
            i_token0.transferFrom(msg.sender, address(this), _amountIn);
            amountIn = i_token0.balanceOf(address(this)) - s_reserve0;
        }
        else {
            i_token1.transferFrom(msg.sender, address(this), _amountIn);
            amountIn = i_token0.balanceOf(address(this)) - s_reserve1;
        }
        
        // calculate amount with Fee 
        // 0.3% fee
        _amountOut = (amountIn * 997)/1000;

        if (_tokenIn == address(i_token0)) {
            _update(s_reserve0 + amountIn, s_reserve1 - _amountOut);
        }
        else {
            _update(s_reserve0 - _amountOut, s_reserve1 + amountIn);
        }

        // transfer token out 
        if (_tokenIn == address(i_token0)) {
            i_token0.transfer(msg.sender, _amountOut);
        }
        else {
            i_token1.transfer(msg.sender, _amountOut);
        }

        emit SwapToken(msg.sender, _tokenIn, _amountOut, amountIn);
    }

    function refactorSwap(address _tokenIn, uint256 _amountIn) external returns (uint256 amountOut){
        if (_tokenIn == address(0)) {
            revert CSAMM__ZeroAddress();
        }

        if (_amountIn == 0) {
            revert CSAMM__ZeroAmountNotAllowed();
        }
        
        if (_tokenIn != address(i_token0) && _tokenIn != address(i_token1)) {
            revert CSAMM__NotValidToken();
        }

        bool istoken0 = _tokenIn == address(i_token0);

        (IERC20 tokenIn, IERC20 tokenOut, uint256 resIn, uint256 resOut) = istoken0 ? 
        (i_token0,i_token1,s_reserve0,s_reserve1) : (i_token1,i_token0, s_reserve1, s_reserve0);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        uint256 amountIn = tokenIn.balanceOf(address(this)) - resIn;

        amountOut = (amountIn * 997)/ 1000;

        (uint256 res0, uint256 res1) = istoken0 ? 
        (resIn + amountIn, resOut - amountOut) : (resIn - amountIn, resOut + amountOut);

        _update(res0, res1);

        tokenOut.transfer(msg.sender, amountOut);

        emit SwapToken(msg.sender, _tokenIn, amountOut, amountIn);
    }


    function addLiquidity(uint256 _amount0, uint256 _amount1) external returns (uint256 shares) {
        if (_amount0 == 0 || _amount1 == 0) {
            revert CSAMM__ZeroAmountNotAllowed();
        }

        i_token0.transferFrom(msg.sender, address(this), _amount0);
        i_token1.transferFrom(msg.sender, address(this), _amount1);

        uint256 bal0 = i_token0.balanceOf(address(this));
        uint256 bal1 = i_token1.balanceOf(address(this));

        uint256 d0 = bal0 - s_reserve0;
        uint256 d1 = bal1 - s_reserve1;

        if (s_totalSupply == 0) {
            unchecked {
                shares = d0 + d1;
            }
        } else {
            shares = ((d0 + d1) * s_totalSupply)/(s_reserve0 + s_reserve1); 
        }

        if (shares == 0) {
            revert CSAMM__NullSharesMinted();
        }

        _mint(msg.sender, shares);

        _update(bal0, bal1);

        emit LiquidityAdded(msg.sender, shares, _amount0, _amount1);

    }


    function removeLiquidity(uint256 _shares) external returns (uint256 d0, uint256 d1)
    {
        assembly {
            if iszero(_shares) {
                revert(0,0)
            }
        }

        if (s_balanceOf[msg.sender] <= 0) {
            revert CSAMM__DidNotDepositLiquidity();
        }

        d0 = (s_reserve0 * _shares) / s_totalSupply;
        d1 = (s_reserve1 * _shares) / s_totalSupply;

        _burn(msg.sender,_shares);
        
        _update(s_reserve0 - d0, s_reserve1 - d1);

        if (d0 > 0 ) {
            i_token0.transfer(msg.sender, d0);
        }

        if (d1 > 0) {
            i_token1.transfer(msg.sender, d1);
        }

        emit LiquidityRemoved(msg.sender, d0, d1);
    }

    ////////////////////////////////////////////////////
    ///////// GETTER FUNCTIONS /////////////////////////
    ////////////////////////////////////////////////////

    function getToken0() public view returns (address) {
        return address(i_token0);
    }

    function getToken1() public view returns (address) {
        return address(i_token1);
    }

    function getReserve0() public view returns (uint256) {
        return s_reserve0;
    }

    function getReserve1() public view returns (uint256) {
        return s_reserve1;
    }

    function getTotalSupplyShares() public view returns (uint256) {
        return s_totalSupply;
    }

    function getBalanceOf(address owner) public view returns (uint256) {
        return s_balanceOf[owner];
    }
}