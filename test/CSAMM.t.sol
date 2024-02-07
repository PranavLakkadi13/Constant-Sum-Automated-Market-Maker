// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { CSAMM } from "../src/CSAMM.sol";
import { IERC20 } from "../src/IERC20.sol";
import { MockBTC } from "../src/MockERC20.sol";

contract CSAMMTest is Test {

    event LiquidityAdded(address indexed sender,uint256 indexed shares,uint256 amountToken0Added, uint256 amountToken1Added);
    event LiquidityRemoved(address indexed sender, uint256 indexed amountToken0Out, uint256 indexed amountToken1Out);
    event SwapToken(address sender, address indexed token, uint256 indexed amountReturned, uint256 indexed amountDepositedTowap);

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

    function testRevertOnZerosharesRemoval() public {
        vm.expectRevert();
        protocol.removeLiquidity(0);
    }

    function testSwap() public {
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        protocol.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        protocol.getToken0();
        protocol.getToken1();

        vm.startPrank(darth);
        btc.approve(address(protocol), 10e18);
        protocol.swap(address(btc), 5e18);
        vm.stopPrank();
    }

    function testRefactorSwap() public {
        vm.startPrank(bob);
        btc.approve(address(protocol),1000e18);
        eth.approve(address(protocol), 1000e18);
        protocol.addLiquidity(100e18, 100e18);
        vm.stopPrank();

        protocol.getToken0();
        protocol.getToken1();

        vm.startPrank(darth);
        btc.approve(address(protocol), 10e18);
        protocol.refactorSwap(address(btc), 5e18);
        vm.stopPrank();
    }

    function testFAilOnZeroAmountSwap() public {
        vm.startPrank(darth);
        btc.approve(address(protocol), 10e18);
        vm.expectRevert();
        protocol.refactorSwap(address(btc), 0);
        vm.stopPrank();

        vm.expectRevert(CSAMM.CSAMM__ZeroAmountNotAllowed.selector);
        protocol.swap(address(btc),0);
    }

    function testWhenAddress0ofTokens() public {
        vm.expectRevert(CSAMM.CSAMM__ZeroAddress.selector);
        protocol.swap(address(0),1);
    }

    function testRevertonNullAddressSwap() public {
        vm.expectRevert(CSAMM.CSAMM__ZeroAddress.selector);
        protocol.swap(address(0), 1000e18);

        vm.expectRevert(CSAMM.CSAMM__ZeroAddress.selector);
        protocol.refactorSwap(address(0), 11);
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

    function testAddliquidity() public {
        uint32 amount = 1000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        uint256 y = protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        uint256 x = protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        assertEq(y, x);
    }
    
    function testRemoveLiquidity() public {
        uint32 amount = 1000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.prank(bob);
        protocol.removeLiquidity(100);

        uint256 x = protocol.getTotalSupplyShares();
        assert(x  == 3900);
    }

    function testRemoveLiquiditySHouldFailWhenANullUserCalls() public {
        uint32 amount = 1000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();
        
        // When testing custom errors use the type of the contrcat instead of the object of the contract
        vm.expectRevert(CSAMM.CSAMM__DidNotDepositLiquidity.selector);
        protocol.removeLiquidity(100);
    }

    function testSwaping() public {
        uint32 amount = 10000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        btc.approve(address(protocol),amount);

        address token0 = protocol.getToken0();
        assertEq(token0, address(btc));

        uint256 x = protocol.swap(address(btc), amount);
        vm.stopPrank();

        assert(x == 9970);
    }

    function testRefactorSwaping() public {
        uint32 amount = 10000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        vm.expectEmit(true, true, false, false);
        emit LiquidityAdded(address(bob), 2 * amount, amount, amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        vm.expectEmit(false, true, true , true);
        emit SwapToken(address(bob), address(btc), 9970, amount);
        uint256 x = protocol.refactorSwap(address(btc), amount);
        vm.stopPrank();

        assert(x == 9970);
    }

    function testReservesAfterSwaps() public {
        uint32 amount = 10000;
        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        vm.expectEmit(true, true, false, false);
        emit LiquidityAdded(address(bob), 2 * amount, amount, amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(darth);
        btc.approve(address(protocol),amount);
        eth.approve(address(protocol),amount);
        protocol.addLiquidity(amount, amount);
        vm.stopPrank();

        vm.startPrank(bob);
        btc.approve(address(protocol),amount);
        vm.expectEmit(false, true, true , true);
        emit SwapToken(address(bob), address(btc), 9970, amount);
        uint256 x = protocol.refactorSwap(address(btc), amount);
        vm.stopPrank();

        assert(protocol.getReserve0() == 30000);
        assert(protocol.getReserve1() == (20000 - 9970));

        assertEq(x, 9970);
    }

    function testFailOnSwappingWrongToken() public {
        // vm.expectRevert();
        protocol.swap(address(bob), 1000);
    }
    
}