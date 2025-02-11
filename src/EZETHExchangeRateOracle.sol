// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IEZETHExchangeRateOracle {
    function calculateTVLs() external view returns (uint256[][] memory, uint256[] memory, uint256);
    function ezETH() external view returns (address);
}

interface IEZETH {
    function totalSupply() external view returns (uint256);
}

/**
 *  @title EZETHExchangeRateOracle
 *  @dev   Provides ezETH / USD by multiplying the ezETH exchange rate by ETH / USD.
 *         This provides a "non-market" price. Any depeg event will be ignored.
 */
contract EZETHExchangeRateOracle {

    /// @notice Renzo restaked eth rate source oracle contract.
    IEZETHExchangeRateOracle public immutable oracle;

    /// @notice Renzo restaked eth token contract.
    IEZETH public immutable ezETH;

    /// @notice The price source for ETH / USD.
    IPriceSource public immutable ethSource;

    constructor(address _oracle, address _ethSource) {
        // 8 decimals required as AaveOracle assumes this
        require(IPriceSource(_ethSource).decimals() == 8, "EZETHExchangeRateOracle/invalid-decimals");
        
        oracle    = IEZETHExchangeRateOracle(_oracle);
        ezETH     = IEZETH(oracle.ezETH());
        ethSource = IPriceSource(_ethSource);
    }

    function latestAnswer() external view returns (int256) {
        int256 ethUsd       = ethSource.latestAnswer();
        ( ,, uint256 tvl )  = oracle.calculateTVLs();
        int256 exchangeRate = int256(tvl * 1e18 / ezETH.totalSupply());

        if (ethUsd <= 0 || exchangeRate <= 0) {
            return 0;
        }

        return exchangeRate * ethUsd / 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

}
