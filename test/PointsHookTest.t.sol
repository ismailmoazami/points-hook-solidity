// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import "forge-std/console.sol";
import {PointsHook} from "src/PointsHook.sol"; 

contract PointsHookTest is Test, Deployers {

    using CurrencyLibrary for Currency; 

    Currency ethAddress = Currency.wrap(address(0));
    Currency tokenCurrency; 
    MockERC20 token;
    PointsHook hook; 

    function setUp() external {
        deployFreshManagerAndRouters();

        token = new MockERC20("Token", "TKN", 18);
        tokenCurrency = Currency.wrap(address(token)); 

        token.mint(address(this), 1000e18);
        token.mint(address(1), 1000e18);

        uint160 flags = uint160(Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "PointsHook.sol",
            abi.encode(manager, address(token)),
            address(flags)
        );
        hook = PointsHook(address(flags));

        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);

        (key, ) = initPool(ethAddress, tokenCurrency, hook, 3000, SQRT_PRICE_1_1);
        
    }

    function test_can_add_liquidity_and_swap() external {
        uint256 startingPoints = token.balanceOf(address(this));
        console.log("BeforeAddLiquidity: ", startingPoints);
        bytes memory hookData = hook.getHookData(address(this), address(0));

        uint160 sqrtPriceAtTickLower  = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickHigher = TickMath.getSqrtPriceAtTick(60);

        uint256 ethToAdd = 0.1 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            ethToAdd
        );

        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
            sqrtPriceAtTickLower,
            SQRT_PRICE_1_1,
            liquidityDelta
            );

        modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
            key, 
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: int256(uint256(liquidityDelta)),
                salt: bytes32(0)
            }),
            hookData
        );

        uint256 endingPoints = token.balanceOf(address(this)); 
        console.log("AfterAddLiquidity: ", endingPoints);
        assertApproxEqAbs(startingPoints - endingPoints, 0.1 ether, 0.001 ether);

        swapRouter.swap{value: 0.001 ether} (
            key, 
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            hookData
        );

        uint256 expected = 0.001 ether / 5;
        uint256 pointsAfterSwap = token.balanceOf(address(this)); 
        console.log("pointsAfterSwap", pointsAfterSwap);
        assertEq(pointsAfterSwap - endingPoints, expected);
    }
    

}