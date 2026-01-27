// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPriceSource } from "./interfaces/IPriceSource.sol";

interface IWEETHLike {
    function getRate() external view returns (uint256 rate);
}

/**
 * @title  WEETHRatioOracle
 * @notice Returns the eETH/ETH peg ratio for KillSwitch consumption.
 * @dev    Calculates: (weETH/ETH market price) / (weETH exchange rate) = eETH/ETH ratio
 *         Returns 1e18 when eETH is perfectly pegged to ETH.
 */
contract WEETHRatioOracle {

    /// @notice weETH token contract.
    address public immutable weeth;

    /// @notice weETH/ETH price feed (18 decimals).
    address public immutable weethETHFeed;

    constructor(address weeth_, address weethETHFeed_) {
        require(
            IPriceSource(weethETHFeed_).decimals() == 18,
            "WEETHRatioOracle/invalid-feed-decimals"
        );

        weeth        = weeth_;
        weethETHFeed = weethETHFeed_;
    }

    /**
     * @notice Returns the eETH/ETH peg ratio in 1e18 precision.
     * @return ratio The peg ratio (1e18 = perfect peg, < 1e18 = depegged).
     */
    function latestAnswer() external view returns (int256 ratio) {
        int256  weethETHPrice = IPriceSource(weethETHFeed).latestAnswer(); // weETH/ETH
        uint256 weethRate     = IWEETHLike(weeth).getRate(); // weETH/eETH

        // eETH/ETH ratio = (weETH/ETH) * 1e18 / (weETH/eETH)
        // Both weethETHPrice and weethRate are 18 decimals, result is 1e18 precision
        return (weethETHPrice <= 0 || weethRate == 0) ? int256(0) : (weethETHPrice * 1e18) / int256(weethRate);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

}
