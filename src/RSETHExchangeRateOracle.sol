// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IKelpDAORestakedEthOracle {
    function rsETHPrice() external view returns (uint256);
}

/**
 *  @title RSETHExchangeRateOracle
 *  @dev   Provides rsETH / USD by multiplying the rsETH exchange rate by ETH / USD.
 *         This provides a "non-market" price. Any depeg event will be ignored.
 */
contract RSETHExchangeRateOracle {

    /// @notice KelpDAO restaked eth rate source oracle contract.
    IKelpDAORestakedEthOracle public immutable oracle;

    /// @notice The price source for ETH / USD.
    IPriceSource public immutable ethSource;

    constructor(address _oracle, address _ethSource) {
        // 8 decimals required as AaveOracle assumes this
        require(IPriceSource(_ethSource).decimals() == 8, "RSETHExchangeRateOracle/invalid-decimals");
        
        oracle    = IKelpDAORestakedEthOracle(_oracle);
        ethSource = IPriceSource(_ethSource);
    }

    function latestAnswer() external view returns (int256) {
        int256 ethUsd       = ethSource.latestAnswer();
        int256 exchangeRate = int256(oracle.rsETHPrice());

        if (ethUsd <= 0 || exchangeRate <= 0) {
            return 0;
        }

        return exchangeRate * ethUsd / 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

}
