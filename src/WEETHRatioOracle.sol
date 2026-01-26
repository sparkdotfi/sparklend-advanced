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
 */
contract WEETHRatioOracle {

    /// @notice Chainlink weETH/ETH price feed (18 decimals).
    AggregatorV3Interface public immutable weethEthFeed;

    /// @notice weETH token contract.
    IWeETH public immutable weeth;

    /// @notice Maximum age of Chainlink price data before considered stale.
    uint256 public immutable stalenessThreshold;

    constructor(address _weeth, address _weethEthFeed, uint256 _stalenessThreshold) {
        require(
            AggregatorV3Interface(_weethEthFeed).decimals() == 18,
            "WEETHRatioOracle/invalid-feed-decimals"
        );
        require(_stalenessThreshold > 0, "WEETHRatioOracle/invalid-staleness");

        weethEthFeed       = AggregatorV3Interface(_weethEthFeed);
        weeth              = IWeETH(_weeth);
        stalenessThreshold = _stalenessThreshold;
    }

    /**
     * @notice Returns the eETH/ETH peg ratio in 1e18 precision.
     * @return ratio The peg ratio (1e18 = perfect peg, < 1e18 = depegged).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  weethEthPrice = _getPrice(weethEthFeed, stalenessThreshold); // weETH/ETH
        uint256 weethRate     = weeth.getRate(); // weETH/eETH

        if (weethEthPrice <= 0 || weethRate == 0) return 0;

        // eETH/ETH ratio = (weETH/ETH) * 1e18 / (weETH/eETH)
        // Both weethEthPrice and weethRate are 18 decimals, result is 1e18
        ratio = (weethEthPrice * 1e18) / int256(weethRate);
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
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        if (answer <= 0) return 0;

        if (
            updatedAt == 0 ||
            block.timestamp - updatedAt > _stalenessThreshold ||
            answeredInRound < roundId
        ) return 0;

        return answer;
    }

}