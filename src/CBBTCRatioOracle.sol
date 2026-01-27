// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

/**
 * @title  CBBTCRatioOracle
 * @notice Returns the cbBTC/BTC peg ratio for KillSwitch consumption.
 * @dev    Calculates: (cbBTC/USD) / (BTC/USD) = cbBTC/BTC ratio
 *         Returns 1e18 when cbBTC is perfectly pegged to BTC.
 */
contract CBBTCRatioOracle {

    /// @notice BTC/USD price feed (8 decimals).
    address public immutable btcUSDFeed;

    /// @notice cbBTC/USD price feed (8 decimals).
    address public immutable cbbtcUSDFeed;

    constructor(address btcUSDFeed_, address cbbtcUSDFeed_) {
        require(
            IPriceSource(btcUSDFeed_).decimals() == 8,
            "CBBTCRatioOracle/invalid-btc-decimals"
        );

        require(
            IPriceSource(cbbtcUSDFeed_).decimals() == 8,
            "CBBTCRatioOracle/invalid-cbbtc-decimals"
        );

        btcUSDFeed   = btcUSDFeed_;
        cbbtcUSDFeed = cbbtcUSDFeed_;
    }

    /**
     * @notice Returns the cbBTC/BTC peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = perfect peg, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256 cbbtcUSDPrice = IPriceSource(cbbtcUSDFeed).latestAnswer(); // cbBTC/USD
        int256 btcUSDPrice   = IPriceSource(btcUSDFeed).latestAnswer(); // BTC/USD

        // cbBTC/BTC ratio = (cbBTC/USD) * 1e18 / (BTC/USD)
        // Both prices are 8 decimals, they cancel out, result is 1e18
        return (cbbtcUSDPrice <= 0 || btcUSDPrice <= 0) ? int256(0) : (cbbtcUSDPrice * 1e18) / btcUSDPrice;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

}
