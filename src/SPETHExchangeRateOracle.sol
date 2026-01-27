// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IERC4626Like {
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
}

/**
 * @title  SPETHExchangeRateOracle
 * @notice Provides spETH / USD price using ERC-4626 exchange rate × ETH/USD.
 * @dev    This is a "non-market" price. Any depeg event will be ignored.
 *         spETH (Spark Savings ETH) is an ERC-4626 vault holding WETH.
 */
contract SPETHExchangeRateOracle {

    /// @notice spETH vault contract (ERC-4626).
    address public immutable speth;

    /// @notice The price source for ETH / USD.
    address public immutable ethSource;

    constructor(address speth_, address ethSource_) {
        // 8 decimals required as AaveOracle assumes this
        require(IPriceSource(ethSource_).decimals() == 8, "SPETHExchangeRateOracle/invalid-decimals");

        speth     = speth_;
        ethSource = ethSource_;
    }

    function latestAnswer() external view returns (int256) {
        int256 ethUsd       = IPriceSource(ethSource).latestAnswer();
        int256 exchangeRate = int256(IERC4626Like(speth).convertToAssets(1e18));

        return (ethUsd <= 0 || exchangeRate <= 0) ? int256(0) : (exchangeRate * ethUsd) / 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

}
