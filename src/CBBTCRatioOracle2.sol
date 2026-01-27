// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

/**
 * @title  CbBTCRatioOracle
 * @notice Returns the cbBTC/BTC peg ratio for KillSwitch consumption.
 * @dev    Calculates: (cbBTC/USD) / (BTC/USD) = cbBTC/BTC ratio
 *         Returns 1e18 when cbBTC is perfectly pegged to BTC.
 */
contract CbBTCRatioOracle {

    /// @notice cbBTC/USD price feed (8 decimals).
    IPriceSource public immutable cbbtcUsdFeed;

    /// @notice BTC/USD price feed (8 decimals).
    IPriceSource public immutable btcUsdFeed;

    constructor(
        address _cbbtcUsdFeed,
        address _btcUsdFeed
    ) {
        require(
            IPriceSource(_cbbtcUsdFeed).decimals() == 8,
            "CbBTCRatioOracle/invalid-cbbtc-decimals"
        );
        require(
            IPriceSource(_btcUsdFeed).decimals() == 8,
            "CbBTCRatioOracle/invalid-btc-decimals"
        );

        cbbtcUsdFeed = IPriceSource(_cbbtcUsdFeed);
        btcUsdFeed   = IPriceSource(_btcUsdFeed);
    }

    /**
     * @notice Returns the cbBTC/BTC peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = perfect peg, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256 cbbtcUsdPrice = IPriceSource(cbbtcUsdFeed).latestAnswer(); // cbBTC/USD
        int256 btcUsdPrice   = IPriceSource(btcUsdFeed).latestAnswer(); // BTC/USD

        if (cbbtcUsdPrice <= 0 || btcUsdPrice <= 0) return 0;

        // cbBTC/BTC ratio = (cbBTC/USD) * 1e18 / (BTC/USD)
        // Both prices are 8 decimals, they cancel out, result is 1e18
        ratio = (cbbtcUsdPrice * 1e18) / btcUsdPrice;
    }

}
