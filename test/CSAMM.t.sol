// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { CSAMM } from "../src/CSAMM.sol";
import { IERC20 } from "../src/IERC20.sol";
import { MockBTC } from "../src/MockERC20.sol";

contract CSAMMTest is Test {

    MockBTC public btc;
    MockBTC public eth;
    CSAMM public protocol;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address darth = makeAddr("darth");

    function setUp() public {
        vm.startPrank(bob);
        btc = new MockBTC("BITCOIN","BTC");
        eth = new MockBTC("ETHEREUM","ETH");
        protocol = new CSAMM(address(btc),address(eth));
        btc.transfer(address(darth), 1000e18);
        eth.transfer(address(darth), 1000e18);
        vm.stopPrank();
    }

    function testApproval() public {
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        vm.stopPrank();
    }

    function testTokenDeposit() public {
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        protocol.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        uint256 x = btc.balanceOf(address(protocol));
        assert(x == 100e18);
    }

    function testAddLiquidityNullVAlueSHouldFail() public{
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        vm.expectRevert();
        protocol.addLiquidity(0, 0);
        vm.stopPrank();
    }

    function testRevertonNullAddressSwap() public {
        vm.expectRevert();
        protocol.swap(address(0), 1000e18);
    }

    function testRevertOnNulladdressTokenTransfer() public {
        vm.startPrank(bob);
        vm.expectRevert();
        btc.transfer(address(0),100);
        vm.stopPrank();
    }

    function testReturnSharesOnAddLiquidity() public {
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        uint256 x = protocol.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        assertEq(x, 200e18);
    }

    function testGetterfunctions() public  {
        IERC20 token0 = IERC20(protocol.getToken0());
        IERC20 token1 = IERC20(protocol.getToken1());
        uint256 totalsupply = protocol.getTotalSupplyShares();
        uint256 reserve0 = protocol.getReserve0();
        uint256 reserve1 = protocol.getReserve1();
        uint256 bal = protocol.getBalanceOf(address(0));

        assert(token0 == IERC20(address(btc)));
        assert(token1 == IERC20(address(eth)));
        assertEq(totalsupply, 0);
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(bal, 0);
    }

    
    
}