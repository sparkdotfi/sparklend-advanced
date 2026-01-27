// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

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

    /// @notice rETH/ETH price feed (18 decimals).
    IPriceSource public immutable rethEthFeed;

    /// @notice rETH token contract.
    IRocketTokenRETH public immutable reth;

    constructor(
        address _reth,
        address _rethEthFeed
    ) {
        require(
            IPriceSource(_rethEthFeed).decimals() == 18,
            "RETHRatioOracle/invalid-feed-decimals"
        );

        rethEthFeed = IPriceSource(_rethEthFeed);
        reth        = IRocketTokenRETH(_reth);
    }

    /**
     * @notice Returns the rETH peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = fair value, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  rethEthPrice = IPriceSource(rethEthFeed).latestAnswer(); // rETH/ETH
        uint256 exchangeRate = reth.getExchangeRate(); // rETH/ETH

        if (rethEthPrice <= 0 || exchangeRate == 0) return 0;

        // rETH/ETH ratio = (rETH/ETH) * 1e18 / (rETH/ETH)
        // Both rethEthPrice and exchangeRate are 18 decimals, result is 1e18
        ratio = (rethEthPrice * 1e18) / int256(exchangeRate);
    }

}
