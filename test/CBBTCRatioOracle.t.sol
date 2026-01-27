// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { CBBTCRatioOracle } from "../src/CBBTCRatioOracle.sol";

contract CBBTCRatioOracleTest is Test {

    CBBTCRatioOracle oracle;
    PriceSourceMock  btcUSDFeed;
    PriceSourceMock  cbbtcUSDFeed;

    function setUp() public {
        cbbtcUSDFeed = new PriceSourceMock(100_000e8, 8);
        btcUSDFeed   = new PriceSourceMock(100_000e8, 8);
        oracle       = new CBBTCRatioOracle(address(btcUSDFeed), address(cbbtcUSDFeed));
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() external {
        assertEq(address(oracle.cbbtcUSDFeed()), address(cbbtcUSDFeed));
        assertEq(address(oracle.btcUSDFeed()),   address(btcUSDFeed));
        assertEq(oracle.decimals(),              18);
    }

    function test_constructor_invalidFeedDecimals() external {
        btcUSDFeed.setDecimals(18);

        vm.expectRevert("CBBTCRatioOracle/invalid-btc-decimals");
        new CBBTCRatioOracle(address(btcUSDFeed), address(cbbtcUSDFeed));

        btcUSDFeed.setDecimals(8);
        cbbtcUSDFeed.setDecimals(18);

        vm.expectRevert("CBBTCRatioOracle/invalid-cbbtc-decimals");
        new CBBTCRatioOracle(address(btcUSDFeed), address(cbbtcUSDFeed));
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() external {
        // cbBTC/USD = 100000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 100000e8 * 1e18 / 100000e8 = 1e18 (perfect peg)
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() external {
        // cbBTC/USD = 99000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 99000e8 * 1e18 / 100000e8 = 0.99e18 (discount)
        cbbtcUSDFeed.setLatestAnswer(99_000e8);
        assertEq(oracle.latestAnswer(), 0.99e18);
    }

    function test_latestAnswer_premium() external {
        // cbBTC/USD = 101000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 101000e8 * 1e18 / 100000e8 = 1.01e18 (premium)
        cbbtcUSDFeed.setLatestAnswer(101_000e8);
        assertEq(oracle.latestAnswer(), 1.01e18);
    }

    function test_latestAnswer_zeroCBBTCPrice() external {
        cbbtcUSDFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeCBBTCPrice() external {
        cbbtcUSDFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroBTCPrice() external {
        btcUSDFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeBTCPrice() external {
        btcUSDFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroCBBTCBTCPrice() external {
        cbbtcUSDFeed.setLatestAnswer(0);
        btcUSDFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 cbbtcUSDPrice,
        uint256 btcUSDPrice
    ) external {
        // Bound to realistic ranges to avoid overflow (BTC prices in 8 decimals)
        cbbtcUSDPrice = bound(cbbtcUSDPrice, 1_000e8, 200_000e8); // $1k-$200k
        btcUSDPrice   = bound(btcUSDPrice,   1_000e8, 200_000e8);

        cbbtcUSDFeed.setLatestAnswer(int256(cbbtcUSDPrice));
        btcUSDFeed.setLatestAnswer(int256(btcUSDPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((cbbtcUSDPrice * 1e18) / btcUSDPrice);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 price) external {
        // When cbBTC and BTC prices are equal, ratio should be 1e18
        price = bound(price, 1_000e8, 200_000e8);

        cbbtcUSDFeed.setLatestAnswer(int256(price));
        btcUSDFeed.setLatestAnswer(int256(price));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCBBTCPrice(int256 price) external {
        // Any non-positive cbBTC price should return 0
        price = bound(price, type(int256).min, 0);

        cbbtcUSDFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidBTCPrice(int256 price) external {
        // Any non-positive BTC price should return 0
        price = bound(price, type(int256).min, 0);

        btcUSDFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCBBTCBTCPrice(int256 price) external {
        // Any non-positive cbBTC & BTC price should return 0
        price = bound(price, type(int256).min, 0);

        cbbtcUSDFeed.setLatestAnswer(price);
        btcUSDFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

}
