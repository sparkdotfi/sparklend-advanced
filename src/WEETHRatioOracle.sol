// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

interface IWeETH {
    function getRate() external view returns (uint256);
}

/**
 * @title  WEETHRatioOracle
 * @notice Returns the eETH/ETH peg ratio for KillSwitch consumption.
 * @dev    Calculates: (weETH/ETH market price) / (weETH exchange rate) = eETH/ETH ratio
 *         Returns 1e18 when eETH is perfectly pegged to ETH.
 *         Supports L2 deployments with sequencer uptime check.
 */
contract WEETHRatioOracle {

    /// @notice Chainlink weETH/ETH price feed (18 decimals).
    AggregatorV3Interface public immutable weethEthFeed;

    /// @notice L2 Sequencer Uptime Feed. Set to address(0) for L1/non-rollup chains.
    AggregatorV3Interface public immutable sequencerUptimeFeed;

    /// @notice weETH token contract.
    IWeETH public immutable weeth;

    /// @notice Maximum age of Chainlink price data before considered stale.
    uint256 public immutable stalenessThreshold;

    /// @notice Grace period after sequencer comes back up before trusting prices.
    uint256 public immutable gracePeriod;

    constructor(
        address _weeth,
        address _weethEthFeed,
        uint256 _stalenessThreshold,
        address _sequencerUptimeFeed,
        uint256 _gracePeriod
    ) {
        require(
            AggregatorV3Interface(_weethEthFeed).decimals() == 18,
            "WEETHRatioOracle/invalid-feed-decimals"
        );
        require(_stalenessThreshold > 0, "WEETHRatioOracle/invalid-staleness");
        require(
            (_sequencerUptimeFeed == address(0)) == (_gracePeriod == 0),
            "WEETHRatioOracle/invalid-sequencer-config"
        );

        weethEthFeed         = AggregatorV3Interface(_weethEthFeed);
        weeth                = IWeETH(_weeth);
        stalenessThreshold   = _stalenessThreshold;
        sequencerUptimeFeed  = AggregatorV3Interface(_sequencerUptimeFeed);
        gracePeriod          = _gracePeriod;
    }

    /**
     * @notice Returns the eETH/ETH peg ratio in 1e18 precision.
     * @return ratio The peg ratio (1e18 = perfect peg, < 1e18 = depegged).
     */
    function latestAnswer() external view returns (int256 ratio) {
        // Check L2 sequencer status if configured
        if (address(sequencerUptimeFeed) != address(0)) {
            if (!_isSequencerUp()) return 0;
        }

        int256  weethEthPrice = _getPrice(weethEthFeed, stalenessThreshold); // weETH/ETH
        uint256 weethRate     = weeth.getRate(); // weETH/eETH

        if (weethEthPrice <= 0 || weethRate == 0) return 0;

        // eETH/ETH ratio = (weETH/ETH) * 1e18 / (weETH/eETH)
        // Both weethEthPrice and weethRate are 18 decimals, result is 1e18
        ratio = (weethEthPrice * 1e18) / int256(weethRate);
    }

    /**
     * @dev    Checks if the L2 sequencer is up and grace period has passed.
     * @return True if sequencer is up and grace period has elapsed.
     */
    function _isSequencerUp() internal view returns (bool) {
        (
            ,
            int256 answer,
            uint256 startedAt,
            ,
        ) = sequencerUptimeFeed.latestRoundData();

        // answer == 0: Sequencer is up, answer == 1: Sequencer is down
        // startedAt returns 0 only on Arbitrum when the Sequencer Uptime contract is not yet initialized.
        // For L2 chains other than Arbitrum, startedAt is set to block.timestamp on construction.
        if (answer != 0 || startedAt == 0) return false;

        // Ensure grace period has passed since sequencer came back up
        return block.timestamp - startedAt > gracePeriod;
    }

    /**
     * @dev    Fetches price from Chainlink feed and validates freshness.
     * @param  feed                The Chainlink price feed.
     * @param  _stalenessThreshold Maximum age of price data in seconds.
     * @return price               The price, or 0 if invalid/stale.
     */
    function _getPrice(
        AggregatorV3Interface feed,
        uint256 _stalenessThreshold
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
            block.timestamp - updatedAt > _stalenessThreshold
        ) return 0;

        return answer;
    }

}