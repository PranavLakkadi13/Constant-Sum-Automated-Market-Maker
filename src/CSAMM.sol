// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "./IERC20.sol";

contract CSAMM {

    ////////////////////////////////////////////////////
    ///////// Errors ///////////////////////////////////
    ////////////////////////////////////////////////////

    error CSAMM__NotValidToken();
    error CSAMM__ZeroAddress();

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
    ///////// Extrenal Functions ///////////////////////
    ////////////////////////////////////////////////////

    function swap(address _tokenIn, uint256 _amountIn) external returns (uint256 _amountOut) {
        if (_tokenIn != address(i_token0) || _tokenIn != address(i_token1)) {
            revert CSAMM__NotValidToken();
        }
        
        if (_tokenIn == address(0)) {
            revert CSAMM__ZeroAddress();
        }

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
    }


    function addLiquidity() external {}
    function removeLiquidity() external {}

    ////////////////////////////////////////////////////
    ///////// GETTER FUNCTIONS /////////////////////////
    ////////////////////////////////////////////////////

    function getToken0() public view returns (IERC20) {
        return i_token0;
    }

    function getToken1() public view returns (IERC20) {
        return i_token1;
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