// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { AggregatorV3Mock } from "./mocks/AggregatorV3Mock.sol";

import { CbBTCRatioOracle } from "../src/CbBTCRatioOracle.sol";

contract CbBTCRatioOracleTest is Test {

    AggregatorV3Mock cbbtcUsdFeed;
    AggregatorV3Mock btcUsdFeed;

    CbBTCRatioOracle oracle;

    uint256 constant STALENESS_THRESHOLD_CBBTC = 1 days;
    uint256 constant STALENESS_THRESHOLD_BTC   = 1 days;

    function setUp() public {
        cbbtcUsdFeed = new AggregatorV3Mock(8);
        btcUsdFeed   = new AggregatorV3Mock(8);

        // Set valid Chainlink data: cbBTC/USD = 100000e8, BTC/USD = 100000e8
        setBothPrices(100000e8, 100000e8);

        oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC
        );
    }

    /**********************************************************************************************/
    /*** Test Helpers                                                                           ***/
    /**********************************************************************************************/

    /// @dev Sets cbBTC price feed with custom updatedAt timestamp
    function setCbbtcPrice(int256 price, uint256 updatedAt) internal {
        cbbtcUsdFeed.setRoundData({
            _answer    : price,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets cbBTC price feed with current block.timestamp
    function setCbbtcPrice(int256 price) internal {
        setCbbtcPrice(price, block.timestamp);
    }

    /// @dev Sets BTC price feed with custom updatedAt timestamp
    function setBtcPrice(int256 price, uint256 updatedAt) internal {
        btcUsdFeed.setRoundData({
            _answer    : price,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets BTC price feed with current block.timestamp
    function setBtcPrice(int256 price) internal {
        setBtcPrice(price, block.timestamp);
    }

    /// @dev Sets both feeds with current block.timestamp (convenience function)
    function setBothPrices(int256 cbbtcPrice, int256 btcPrice) internal {
        setCbbtcPrice(cbbtcPrice);
        setBtcPrice(btcPrice);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.cbbtcUsdFeed()),           address(cbbtcUsdFeed));
        assertEq(address(oracle.btcUsdFeed()),             address(btcUsdFeed));
        assertEq(oracle.stalenessThresholdCbbtcUsd(),      STALENESS_THRESHOLD_CBBTC);
        assertEq(oracle.stalenessThresholdBtcUsd(),        STALENESS_THRESHOLD_BTC);
    }

    function test_constructor_invalidFeedDecimals() public {
        cbbtcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-cbbtc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC
        );
        
        cbbtcUsdFeed.setDecimals(8);
        btcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-btc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC
        );
    }

    function test_constructor_invalidStalenessZero() public {
        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            0,
            STALENESS_THRESHOLD_BTC
        );

        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            0
        );

        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            0,
            0
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
        cbbtcUsdFeed.setAnswer(99000e8);
        assertEq(oracle.latestAnswer(), 0.99e18);
    }

    function test_latestAnswer_premium() public {
        // cbBTC/USD = 101000e8, BTC/USD = 100000e8
        // cbBTC/BTC ratio = 101000e8 * 1e18 / 100000e8 = 1.01e18 (premium)
        cbbtcUsdFeed.setAnswer(101000e8);
        assertEq(oracle.latestAnswer(), 1.01e18);
    }

    function test_latestAnswer_zeroCbbtcPrice() public {
        cbbtcUsdFeed.setAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeCbbtcPrice() public {
        cbbtcUsdFeed.setAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroBtcPrice() public {
        btcUsdFeed.setAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeBtcPrice() public {
        btcUsdFeed.setAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroCbbtcBTCPrice() public {
        cbbtcUsdFeed.setAnswer(0);
        btcUsdFeed.setAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Chainlink Staleness Tests                                                              ***/
    /**********************************************************************************************/

    function test_latestAnswer_staleCbbtcPrice() public {
        setCbbtcPrice(100000e8);

        vm.warp(block.timestamp + STALENESS_THRESHOLD_CBBTC + 1);
        // cbBTC feed is stale

        // BTC feed is fresh
        setBtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_staleBtcPrice() public {
        setBtcPrice(100000e8);

        // BTC feed is stale
        vm.warp(block.timestamp + STALENESS_THRESHOLD_BTC + 1);

        // cbBTC feed is fresh
        setCbbtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_cbbtcPriceAtThreshold() public {
        setCbbtcPrice(100000e8);

        vm.warp(block.timestamp + STALENESS_THRESHOLD_CBBTC);
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_btcPriceAtThreshold() public {
        setBtcPrice(100000e8);

        vm.warp(block.timestamp + STALENESS_THRESHOLD_BTC);
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_cbbtcBtcPriceAtThreshold() public {
        setBothPrices(100000e8, 100000e8);

        assertEq(STALENESS_THRESHOLD_CBBTC, STALENESS_THRESHOLD_BTC);

        vm.warp(block.timestamp + STALENESS_THRESHOLD_CBBTC);
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_cbbtcUpdatedAtZero() public {
        setCbbtcPrice(100000e8, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_btcUpdatedAtZero() public {
        setBtcPrice(100000e8, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_cbbtcBtcUpdatedAtZero() public {
        setCbbtcPrice(100000e8, 0);
        setBtcPrice(100000e8, 0);

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

        cbbtcUsdFeed.setAnswer(int256(cbbtcUsdPrice));
        btcUsdFeed.setAnswer(int256(btcUsdPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((cbbtcUsdPrice * 1e18) / btcUsdPrice);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 price) public {
        // When cbBTC and BTC prices are equal, ratio should be 1e18
        price = bound(price, 1000e8, 200000e8);

        cbbtcUsdFeed.setAnswer(int256(price));
        btcUsdFeed.setAnswer(int256(price));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCbbtcPrice(int256 price) public {
        // Any non-positive cbBTC price should return 0
        price = bound(price, type(int256).min, 0);
        cbbtcUsdFeed.setAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidBtcPrice(int256 price) public {
        // Any non-positive BTC price should return 0
        price = bound(price, type(int256).min, 0);
        btcUsdFeed.setAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnInvalidCbbtcBtcPrice(int256 price) public {
        // Any non-positive cbBTC & BTC price should return 0
        price = bound(price, type(int256).min, 0);
        
        cbbtcUsdFeed.setAnswer(price);
        btcUsdFeed.setAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_cbbtcStalenessCheck(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, STALENESS_THRESHOLD_CBBTC + 1, 365 days);

        vm.warp(timeDelta + 1);

        uint256 staleTime = block.timestamp - timeDelta;
        setCbbtcPrice(100000e8, staleTime);

        // BTC feed is fresh
        setBtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_btcStalenessCheck(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, STALENESS_THRESHOLD_BTC + 1, 365 days);

        vm.warp(timeDelta + 1);

        uint256 staleTime = block.timestamp - timeDelta;
        setBtcPrice(100000e8, staleTime);

        // cbBTC feed is fresh
        setCbbtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

}
