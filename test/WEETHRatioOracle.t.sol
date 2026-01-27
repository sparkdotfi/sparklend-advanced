// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { WEETHRatioOracle } from "../src/WEETHRatioOracle.sol";

contract WEETHMock {

    uint256 public exchangeRate;

    constructor(uint256 exchangeRate_) {
        exchangeRate = exchangeRate_;
    }

    function getRate() external view returns (uint256 rate) {
        return exchangeRate;
    }

    function setExchangeRate(uint256 exchangeRate_) external {
        exchangeRate = exchangeRate_;
    }

}

contract WEETHRatioOracleTest is Test {

    WEETHRatioOracle oracle;
    WEETHMock        weeth;
    PriceSourceMock  weethETHFeed;

    function setUp() public {
        weeth        = new WEETHMock(1.05e18);
        weethETHFeed = new PriceSourceMock(1.05e18, 18);

        oracle = new WEETHRatioOracle(address(weeth), address(weethETHFeed));
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() external {
        assertEq(oracle.weeth(),        address(weeth));
        assertEq(oracle.weethETHFeed(), address(weethETHFeed));
        assertEq(oracle.decimals(),     18);
    }

    function test_constructor_invalidFeedDecimals() external {
        weethETHFeed.setDecimals(8);

        vm.expectRevert("WEETHRatioOracle/invalid-feed-decimals");
        new WEETHRatioOracle(address(weeth), address(weethETHFeed));
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() external {
        // weETH/ETH price = 1.05e18, weETH rate = 1.05e18
        // eETH/ETH ratio = 1.05e18 * 1e18 / 1.05e18 = 1e18 (perfect peg)
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() external {
        // weETH/ETH price = 1.0e18 (market), weETH rate = 1.05e18 (exchange rate)
        // eETH/ETH ratio = 1.0e18 * 1e18 / 1.05e18 = 952380952380952380 (depegged)
        weethETHFeed.setLatestAnswer(1.0e18);
        assertEq(oracle.latestAnswer(), 0.952380952380952380e18);
    }

    function test_latestAnswer_premium() external {
        // weETH/ETH price = 1.1e18 (market), weETH rate = 1.05e18 (exchange rate)
        // eETH/ETH ratio = 1.1e18 * 1e18 / 1.05e18 = ~1.0476e18 (premium)
        weethETHFeed.setLatestAnswer(1.1e18);
        assertEq(oracle.latestAnswer(), 1.047619047619047619e18);
    }

    function test_latestAnswer_zeroPrice() external {
        weethETHFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativePrice() external {
        weethETHFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroRate() external {
        weeth.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 weethETHPrice,
        uint256 weethRate
    ) external {
        // Bound to realistic ranges to avoid overflow
        weethETHPrice = bound(weethETHPrice, 1, 100e18);
        weethRate     = bound(weethRate,     1, 100e18);

        weeth.setExchangeRate(weethRate);
        weethETHFeed.setLatestAnswer(int256(weethETHPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((weethETHPrice * 1e18) / weethRate);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 value) external {
        // When price equals rate, ratio should be 1e18
        value = bound(value, 1, 100e18);

        weeth.setExchangeRate(value);
        weethETHFeed.setLatestAnswer(int256(value));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidPrice(int256 price) external {
        // Any non-positive price should return 0
        price = bound(price, type(int256).min, 0);

        weethETHFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnZeroRate(uint256 weethETHPrice) external {
        weethETHPrice = bound(weethETHPrice, 1, 100e18);

        weethETHFeed.setLatestAnswer(int256(weethETHPrice));
        weeth.setExchangeRate(0);

        assertEq(oracle.latestAnswer(), 0);
    }

}
