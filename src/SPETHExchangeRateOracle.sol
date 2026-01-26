// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IERC4626 {
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/**
 * @title  SPETHExchangeRateOracle
 * @notice Provides spETH / USD price using ERC-4626 exchange rate × ETH/USD.
 * @dev    This is a "non-market" price. Any depeg event will be ignored.
 *         spETH (Spark Savings ETH) is an ERC-4626 vault holding WETH.
 */
contract SPETHExchangeRateOracle {

    /// @notice spETH vault contract (ERC-4626).
    IERC4626 public immutable speth;

    /// @notice The price source for ETH / USD.
    IPriceSource public immutable ethSource;

    constructor(address _speth, address _ethSource) {
        // 8 decimals required as AaveOracle assumes this
        require(IPriceSource(_ethSource).decimals() == 8, "SPETHExchangeRateOracle/invalid-decimals");

        speth     = IERC4626(_speth);
        ethSource = IPriceSource(_ethSource);
    }

    function latestAnswer() external view returns (int256) {
        int256 ethUsd       = ethSource.latestAnswer();
        int256 exchangeRate = int256(speth.convertToAssets(1e18));

        if (ethUsd <= 0 || exchangeRate <= 0) {
            return 0;
        }

        return exchangeRate * ethUsd / 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

}
