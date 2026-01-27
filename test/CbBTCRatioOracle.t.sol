// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { CbBTCRatioOracle } from "../src/CbBTCRatioOracle.sol";

contract CbBTCRatioOracleTest is Test {

    PriceSourceMock cbbtcUsdFeed;
    PriceSourceMock btcUsdFeed;

    CbBTCRatioOracle oracle;

    function setUp() public {
        cbbtcUsdFeed = new PriceSourceMock(100000e8, 8);
        btcUsdFeed   = new PriceSourceMock(100000e8, 8);

        oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed)
        );
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.cbbtcUsdFeed()),           address(cbbtcUsdFeed));
        assertEq(address(oracle.btcUsdFeed()),             address(btcUsdFeed));
    }

    function test_constructor_invalidFeedDecimals() public {
        cbbtcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-cbbtc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed)
        );
        
        cbbtcUsdFeed.setDecimals(8);
        btcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-btc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed)
        );
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() public {
        // cbBTC/USD = 100000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 100000e8 * 1e18 / 100000e8 = 1e18 (perfect peg)
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() public {
        // cbBTC/USD = 99000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 99000e8 * 1e18 / 100000e8 = 0.99e18 (discount)
        cbbtcUsdFeed.setLatestAnswer(99000e8);
        assertEq(oracle.latestAnswer(), 0.99e18);
    }

    function test_latestAnswer_premium() public {
        // cbBTC/USD = 101000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 101000e8 * 1e18 / 100000e8 = 1.01e18 (premium)
        cbbtcUsdFeed.setLatestAnswer(101000e8);
        assertEq(oracle.latestAnswer(), 1.01e18);
    }

    function test_latestAnswer_zeroCbbtcPrice() public {
        cbbtcUsdFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeCbbtcPrice() public {
        cbbtcUsdFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroBtcPrice() public {
        btcUsdFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeBtcPrice() public {
        btcUsdFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroCbbtcBTCPrice() public {
        cbbtcUsdFeed.setLatestAnswer(0);
        btcUsdFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 cbbtcUsdPrice,
        uint256 btcUsdPrice
    ) public {
        // Bound to realistic ranges to avoid overflow (BTC prices in 8 decimals)
        cbbtcUsdPrice = bound(cbbtcUsdPrice, 1000e8, 200000e8); // $1k-$200k
        btcUsdPrice   = bound(btcUsdPrice,   1000e8, 200000e8);

        cbbtcUsdFeed.setLatestAnswer(int256(cbbtcUsdPrice));
        btcUsdFeed.setLatestAnswer(int256(btcUsdPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((cbbtcUsdPrice * 1e18) / btcUsdPrice);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 price) public {
        // When cbBTC and BTC prices are equal, ratio should be 1e18
        price = bound(price, 1000e8, 200000e8);

        cbbtcUsdFeed.setLatestAnswer(int256(price));
        btcUsdFeed.setLatestAnswer(int256(price));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCbbtcPrice(int256 price) public {
        // Any non-positive cbBTC price should return 0
        price = bound(price, type(int256).min, 0);
        cbbtcUsdFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidBtcPrice(int256 price) public {
        // Any non-positive BTC price should return 0
        price = bound(price, type(int256).min, 0);
        btcUsdFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCbbtcBtcPrice(int256 price) public {
        // Any non-positive cbBTC & BTC price should return 0
        price = bound(price, type(int256).min, 0);
        
        cbbtcUsdFeed.setLatestAnswer(price);
        btcUsdFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

}
