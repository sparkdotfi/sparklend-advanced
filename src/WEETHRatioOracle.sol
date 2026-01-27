// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

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

    /// @notice weETH/ETH price feed (18 decimals).
    IPriceSource public immutable weethEthFeed;

    /// @notice weETH token contract.
    IWeETH public immutable weeth;

    constructor(
        address _weeth,
        address _weethEthFeed
    ) {
        require(
            IPriceSource(_weethEthFeed).decimals() == 18,
            "WEETHRatioOracle/invalid-feed-decimals"
        );

        weethEthFeed = IPriceSource(_weethEthFeed);
        weeth        = IWeETH(_weeth);
    }

    /**
     * @notice Returns the eETH/ETH peg ratio in 1e18 precision.
     * @return ratio The peg ratio (1e18 = perfect peg, < 1e18 = depegged).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  weethEthPrice = IPriceSource(weethEthFeed).latestAnswer(); // weETH/ETH
        uint256 weethRate     = weeth.getRate(); // weETH/eETH

        if (weethEthPrice <= 0 || weethRate == 0) return 0;

        // eETH/ETH ratio = (weETH/ETH) * 1e18 / (weETH/eETH)
        // Both weethEthPrice and weethRate are 18 decimals, result is 1e18
        ratio = (weethEthPrice * 1e18) / int256(weethRate);
    }

}