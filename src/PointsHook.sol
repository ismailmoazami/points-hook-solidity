// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC20 {

    using CurrencyLibrary for Currency; 
    using BalanceDeltaLibrary for BalanceDelta; 

    uint256 public constant INITIAL_REFERAL_POINTS = 500e18;

    mapping(address user => address referer) public referedBy;

    constructor(IPoolManager _manager, address _token) BaseHook(_manager) ERC20("POINTS", "POINTS", 18) {}

    function getHookPermissions()
            public
            pure
            override
            returns (Hooks.Permissions memory)
        {
            return
                Hooks.Permissions({
                    beforeInitialize: false,
                    afterInitialize: false,
                    beforeAddLiquidity: false,
                    beforeRemoveLiquidity: false,
                    afterAddLiquidity: true,
                    afterRemoveLiquidity: false,
                    beforeSwap: false,
                    afterSwap: true,
                    beforeDonate: false,
                    afterDonate: false,
                    beforeSwapReturnDelta: false,
                    afterSwapReturnDelta: false,
                    afterAddLiquidityReturnDelta: false,
                    afterRemoveLiquidityReturnDelta: false
                });
        }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, BalanceDelta delta, bytes calldata hookData)
        external
        override
        onlyPoolManager
        returns (bytes4, int128) 
    {
        
        if(!key.currency0.isAddressZero()) {
            return(this.afterSwap.selector, 0);
        }

        if(!swapParams.zeroForOne) {
            return(this.afterSwap.selector, 0);
        }
        
        // uint256 points = uint256(int256(-delta.amount0)) / 5;
        uint256 points = swapParams.amountSpecified > 0 
        ? uint256(int256(-delta.amount0())) / 5
        : uint256(int256(-swapParams.amountSpecified)) / 5;
       
        _mintPoints(hookData, points);
        
        return(this.afterSwap.selector, 0);

    }

    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata liquidityParams,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        if(!key.currency0.isAddressZero()) {
            return;
        }

        
    }

    // Internal functions
    function _mintPoints(bytes memory _hookData, uint256 _points) internal {
        (address user, address referer) = abi.decode(_hookData, (address, address));

        if(referedBy[user] == referer) {
            uint256 refererPointToMint = _points / 5;
            _mint(user, _points);
            _mint(referer, refererPointToMint);
            return;
        }

        if(referer != address(0)) {
            uint256 refererPointToMint = _points / 5; 
            _mint(user, _points);
            _mint(referer, refererPointToMint + INITIAL_REFERAL_POINTS);
            return;
        }

        _mint(user, _points);
    }

    // View and Pure functions 
    function getHookData(address user, address referer) public pure returns (bytes memory) {
        return abi.encode(user, referer);
    }

}