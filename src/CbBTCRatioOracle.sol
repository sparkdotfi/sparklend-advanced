// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

/**
 * @title  CbBTCRatioOracle
 * @notice Returns the cbBTC/BTC peg ratio for KillSwitch consumption.
 * @dev    Calculates: (cbBTC/USD) / (BTC/USD) = cbBTC/BTC ratio
 *         Returns 1e18 when cbBTC is perfectly pegged to BTC.
 */
contract CbBTCRatioOracle {

    /// @notice Chainlink cbBTC/USD price feed (8 decimals).
    AggregatorV3Interface public immutable cbbtcUsdFeed;

    /// @notice Chainlink BTC/USD price feed (8 decimals).
    AggregatorV3Interface public immutable btcUsdFeed;

    /// @notice Maximum age of cbBTC/USD Chainlink price data before considered stale.
    uint256 public immutable stalenessThresholdCbbtcUsd;

    /// @notice Maximum age of BTC/USD Chainlink price data before considered stale.
    uint256 public immutable stalenessThresholdBtcUsd;

    constructor(
        address _cbbtcUsdFeed,
        address _btcUsdFeed,
        uint256 _stalenessThresholdCbbtcUsd,
        uint256 _stalenessThresholdBtcUsd
    ) {
        require(
            AggregatorV3Interface(_cbbtcUsdFeed).decimals() == 8,
            "CbBTCRatioOracle/invalid-cbbtc-decimals"
        );
        require(
            AggregatorV3Interface(_btcUsdFeed).decimals() == 8,
            "CbBTCRatioOracle/invalid-btc-decimals"
        );
        require(
            _stalenessThresholdCbbtcUsd > 0 && _stalenessThresholdBtcUsd > 0,
            "CbBTCRatioOracle/invalid-staleness"
        );

        cbbtcUsdFeed               = AggregatorV3Interface(_cbbtcUsdFeed);
        btcUsdFeed                 = AggregatorV3Interface(_btcUsdFeed);
        stalenessThresholdCbbtcUsd = _stalenessThresholdCbbtcUsd;
        stalenessThresholdBtcUsd   = _stalenessThresholdBtcUsd;

    }

    /**
     * @notice Returns the cbBTC/BTC peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = perfect peg, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256 cbbtcUsdPrice = _getPrice(cbbtcUsdFeed, stalenessThresholdCbbtcUsd); // cbBTC/USD
        int256 btcUsdPrice   = _getPrice(btcUsdFeed,   stalenessThresholdBtcUsd); // BTC/USD

        if (cbbtcUsdPrice <= 0 || btcUsdPrice <= 0) return 0;

        // cbBTC/BTC ratio = (cbBTC/USD) * 1e18 / (BTC/USD)
        // Both prices are 8 decimals, they cancel out, result is 1e18
        ratio = (cbbtcUsdPrice * 1e18) / btcUsdPrice;
    }

    /**
     * @dev    Fetches price from Chainlink feed and validates freshness.
     * @param  feed               The Chainlink price feed.
     * @param  stalenessThreshold Maximum age of price data in seconds.
     * @return price              The price, or 0 if invalid/stale.
     */
    function _getPrice(
        AggregatorV3Interface feed,
        uint256 stalenessThreshold
    ) internal view returns (int256 price) {
        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,
        ) = feed.latestRoundData();

        if (answer <= 0) return 0;

        if (
            updatedAt == 0 ||
            block.timestamp - updatedAt > stalenessThreshold
        ) return 0;

        return answer;
    }

}
