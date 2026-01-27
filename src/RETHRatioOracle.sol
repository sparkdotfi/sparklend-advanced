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
 */
contract RETHRatioOracle {

    /// @notice Chainlink rETH/ETH price feed (18 decimals).
    AggregatorV3Interface public immutable rethEthFeed;

    /// @notice rETH token contract.
    IRocketTokenRETH public immutable reth;

    /// @notice Maximum age of Chainlink price data before considered stale.
    uint256 public immutable stalenessThreshold;

    constructor(
        address _reth,
        address _rethEthFeed,
        uint256 _stalenessThreshold
    ) {
        require(
            AggregatorV3Interface(_rethEthFeed).decimals() == 18,
            "RETHRatioOracle/invalid-feed-decimals"
        );
        require(_stalenessThreshold > 0, "RETHRatioOracle/invalid-staleness");

        rethEthFeed         = AggregatorV3Interface(_rethEthFeed);
        reth                = IRocketTokenRETH(_reth);
        stalenessThreshold  = _stalenessThreshold;
    }

    /**
     * @notice Returns the rETH peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = fair value, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  rethEthPrice = _getPrice(rethEthFeed, stalenessThreshold); // rETH/ETH
        uint256 exchangeRate = reth.getExchangeRate(); // rETH/ETH

        if (rethEthPrice <= 0 || exchangeRate == 0) return 0;

        // rETH/ETH ratio = (rETH/ETH) * 1e18 / (rETH/ETH)
        // Both rethEthPrice and exchangeRate are 18 decimals, result is 1e18
        ratio = (rethEthPrice * 1e18) / int256(exchangeRate);
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
