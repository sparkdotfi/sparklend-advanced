// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { RETHRatioOracle } from "../src/RETHRatioOracle.sol";

contract RETHMock {

    uint256 public exchangeRate;

    constructor(uint256 exchangeRate_) {
        exchangeRate = exchangeRate_;
    }

    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }

    function setExchangeRate(uint256 exchangeRate_) external {
        exchangeRate = exchangeRate_;
    }

}

contract RETHRatioOracleTest is Test {

    PriceSourceMock rethETHFeed;
    RETHMock        reth;
    RETHRatioOracle oracle;

    function setUp() public {
        reth        = new RETHMock(1.05e18);
        rethETHFeed = new PriceSourceMock(1.05e18, 18);
        oracle      = new RETHRatioOracle(address(reth), address(rethETHFeed));
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() external {
        assertEq(oracle.reth(),        address(reth));
        assertEq(oracle.rethETHFeed(), address(rethETHFeed));
        assertEq(oracle.decimals(),    18);
    }

    function test_constructor_invalidFeedDecimals() external {
        rethETHFeed.setDecimals(8);

        vm.expectRevert("RETHRatioOracle/invalid-feed-decimals");
        new RETHRatioOracle(address(reth), address(rethETHFeed));
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() external {
        // rETH/ETH price = 1.05e18, rETH exchange rate = 1.05e18
        // rETH/ETH ratio = 1.05e18 * 1e18 / 1.05e18 = 1e18
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() external {
        // rETH/ETH price = 1.0e18 (market), rETH exchange rate = 1.05e18
        // rETH/ETH ratio = 1.0e18 * 1e18 / 1.05e18 = 952380952380952380 (discount)
        rethETHFeed.setLatestAnswer(1.0e18);
        assertEq(oracle.latestAnswer(), 0.952380952380952380e18);
    }

    function test_latestAnswer_premium() external {
        // rETH/ETH price = 1.1e18 (market), rETH exchange rate = 1.05e18
        // rETH/ETH ratio = 1.1e18 * 1e18 / 1.05e18 = ~1.0476e18 (premium)
        rethETHFeed.setLatestAnswer(1.1e18);
        assertEq(oracle.latestAnswer(), 1.047619047619047619e18);
    }

    function test_latestAnswer_zeroPrice() external {
        rethETHFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativePrice() external {
        rethETHFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroRate() external {
        reth.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 marketPrice,
        uint256 exchangeRate
    ) external {
        // Bound to realistic ranges to avoid overflow
        marketPrice  = bound(marketPrice,  1, 100e18);
        exchangeRate = bound(exchangeRate, 1, 100e18);

        reth.setExchangeRate(exchangeRate);
        rethETHFeed.setLatestAnswer(int256(marketPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((marketPrice * 1e18) / exchangeRate);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 exchangeRate) external {
        // When market price equals exchange rate, ratio should be 1e18.
        exchangeRate = bound(exchangeRate, 1, 100e18);

        reth.setExchangeRate(exchangeRate);
        rethETHFeed.setLatestAnswer(int256(exchangeRate));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidPrice(int256 marketPrice) external {
        // Any non-positive market price should return 0
        marketPrice = bound(marketPrice, type(int256).min, 0);

        rethETHFeed.setLatestAnswer(marketPrice);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnZeroRate(uint256 marketPrice) external {
        marketPrice = bound(marketPrice, 1, 100e18);

        rethETHFeed.setLatestAnswer(int256(marketPrice));
        reth.setExchangeRate(0);

        assertEq(oracle.latestAnswer(), 0);
    }

}
