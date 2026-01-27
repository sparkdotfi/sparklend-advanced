// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { AggregatorV3Interface } from "./interfaces/AggregatorV3Interface.sol";

interface IRocketTokenRETH {
    function getExchangeRate() external view returns (uint256);
}

/**
 * @title  RETHRatioOracle
 * @notice Returns the rETH market/fair value ratio for KillSwitch consumption.
 * @dev    Calculates: (rETH/ETH market price) / (rETH exchange rate) = market/fair ratio
 *         Returns 1e18 when rETH market price equals fair value.
 *         Supports L2 deployments with sequencer uptime check.
 */
contract RETHRatioOracle {

    /// @notice Chainlink rETH/ETH price feed (18 decimals).
    AggregatorV3Interface public immutable rethEthFeed;

    /// @notice L2 Sequencer Uptime Feed. Set to address(0) for L1/non-rollup chains.
    AggregatorV3Interface public immutable sequencerUptimeFeed;

    /// @notice rETH token contract.
    IRocketTokenRETH public immutable reth;

    /// @notice Maximum age of Chainlink price data before considered stale.
    uint256 public immutable stalenessThreshold;

    /// @notice Grace period after sequencer comes back up before trusting prices.
    uint256 public immutable gracePeriod;

    constructor(
        address _reth,
        address _rethEthFeed,
        uint256 _stalenessThreshold,
        address _sequencerUptimeFeed,
        uint256 _gracePeriod
    ) {
        require(
            AggregatorV3Interface(_rethEthFeed).decimals() == 18,
            "RETHRatioOracle/invalid-feed-decimals"
        );
        require(_stalenessThreshold > 0, "RETHRatioOracle/invalid-staleness");
        require(
            (_sequencerUptimeFeed == address(0)) == (_gracePeriod == 0),
            "RETHRatioOracle/invalid-sequencer-config"
        );

        rethEthFeed         = AggregatorV3Interface(_rethEthFeed);
        reth                = IRocketTokenRETH(_reth);
        stalenessThreshold  = _stalenessThreshold;
        sequencerUptimeFeed = AggregatorV3Interface(_sequencerUptimeFeed);
        gracePeriod         = _gracePeriod;
    }

    /**
     * @notice Returns the rETH peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = fair value, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        // Check L2 sequencer status if configured
        if (address(sequencerUptimeFeed) != address(0)) {
            if (!_isSequencerUp()) return 0;
        }

        int256  rethEthPrice = _getPrice(rethEthFeed, stalenessThreshold); // rETH/ETH
        uint256 exchangeRate = reth.getExchangeRate(); // rETH/ETH

        if (rethEthPrice <= 0 || exchangeRate == 0) return 0;

        // rETH/ETH ratio = (rETH/ETH) * 1e18 / (rETH/ETH)
        // Both rethEthPrice and exchangeRate are 18 decimals, result is 1e18
        ratio = (rethEthPrice * 1e18) / int256(exchangeRate);
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
        // https://docs.chain.link/data-feeds/l2-sequencer-feeds#example-consumer-contract
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
