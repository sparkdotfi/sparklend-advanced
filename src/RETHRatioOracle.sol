// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IRETHLike {
    function getExchangeRate() external view returns (uint256 rate);
}

/**
 * @title  RETHRatioOracle
 * @notice Returns the rETH market/fair value ratio for KillSwitch consumption.
 * @dev    Calculates: (rETH/ETH market price) / (rETH exchange rate) = market/fair ratio
 *         Returns 1e18 when rETH market price equals fair value.
 */
contract RETHRatioOracle {

    /// @notice rETH token contract.
    address public immutable reth;

    /// @notice rETH/ETH price feed (18 decimals).
    address public immutable rethETHFeed;

    constructor(address reth_, address rethETHFeed_) {
        require(
            IPriceSource(rethETHFeed_).decimals() == 18,
            "RETHRatioOracle/invalid-feed-decimals"
        );

        reth        = reth_;
        rethETHFeed = rethETHFeed_;
    }

    /**
     * @notice Returns the rETH peg ratio in 1e18 precision.
     * @return ratio The ratio (1e18 = fair value, < 1e18 = trading at discount).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  rethEthPrice = IPriceSource(rethETHFeed).latestAnswer(); // rETH/ETH
        uint256 exchangeRate = IRETHLike(reth).getExchangeRate(); // rETH/ETH

        // rETH/ETH ratio = (rETH/ETH) * 1e18 / (rETH/ETH)
        // Both rethEthPrice and exchangeRate are 18 decimals, result is 1e18
        return (rethEthPrice <= 0 || exchangeRate == 0)
            ? int256(0)
            : (rethEthPrice * 1e18) / int256(exchangeRate);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

}
