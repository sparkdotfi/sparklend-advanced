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
    uint256 constant GRACE_PERIOD              = 1 hours;

    function setUp() public {
        cbbtcUsdFeed = new AggregatorV3Mock(8);
        btcUsdFeed   = new AggregatorV3Mock(8);

        // Set valid Chainlink data: cbBTC/USD = 100000e8, BTC/USD = 100000e8
        setBothPrices(100000e8, 100000e8);

        // Deploy without sequencer feed (L1 mode)
        oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(0),
            0
        );
    }

    /**********************************************************************************************/
    /*** Test Helpers                                                                           ***/
    /**********************************************************************************************/

    /// @dev Sets cbBTC price feed with custom timestamps
    function setCbbtcPrice(int256 price, uint256 startedAt, uint256 updatedAt) internal {
        cbbtcUsdFeed.setRoundData({
            _answer    : price,
            _startedAt : startedAt,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets cbBTC price feed with current block.timestamp
    function setCbbtcPrice(int256 price) internal {
        setCbbtcPrice(price, block.timestamp, block.timestamp);
    }

    /// @dev Sets BTC price feed with custom timestamps
    function setBtcPrice(int256 price, uint256 startedAt, uint256 updatedAt) internal {
        btcUsdFeed.setRoundData({
            _answer    : price,
            _startedAt : startedAt,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets BTC price feed with current block.timestamp
    function setBtcPrice(int256 price) internal {
        setBtcPrice(price, block.timestamp, block.timestamp);
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
        assertEq(address(oracle.sequencerUptimeFeed()),    address(0));
        assertEq(oracle.gracePeriod(),                     0);
    }

    function test_constructor_withSequencerFeed() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        assertEq(address(l2Oracle.sequencerUptimeFeed()), address(sequencerFeed));
        assertEq(l2Oracle.gracePeriod(),                  GRACE_PERIOD);
    }

    function test_constructor_invalidFeedDecimals() public {
        cbbtcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-cbbtc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(0),
            0
        );
        
        cbbtcUsdFeed.setDecimals(8);
        btcUsdFeed.setDecimals(18);

        vm.expectRevert("CbBTCRatioOracle/invalid-btc-decimals");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(0),
            0
        );
    }

    function test_constructor_invalidStalenessZero() public {
        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            0,
            STALENESS_THRESHOLD_BTC,
            address(0),
            0
        );

        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            0,
            address(0),
            0
        );

        vm.expectRevert("CbBTCRatioOracle/invalid-staleness");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            0,
            0,
            address(0),
            0
        );
    }

    function test_constructor_invalidSequencerConfig_gracePeriodWithoutFeed() public {
        vm.expectRevert("CbBTCRatioOracle/invalid-sequencer-config");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(0),
            GRACE_PERIOD
        );
    }

    function test_constructor_invalidSequencerConfig_feedWithoutGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        vm.expectRevert("CbBTCRatioOracle/invalid-sequencer-config");
        new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
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
        setCbbtcPrice(100000e8, 0, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_btcUpdatedAtZero() public {
        setBtcPrice(100000e8, 0, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_cbbtcBtcUpdatedAtZero() public {
        setCbbtcPrice(100000e8, 0, 0);
        setBtcPrice(100000e8, 0, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_works_StartedAtZero() public {
        setCbbtcPrice(100000e8, 0, block.timestamp);
        setBtcPrice(100000e8, 0, block.timestamp);

        assertEq(oracle.latestAnswer(), 1e18);
    }

    /**********************************************************************************************/
    /*** L2 Sequencer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_sequencerDown() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        // answer = 1 means sequencer is down
        sequencerFeed.setRoundData({
            _answer    : 1,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        assertEq(l2Oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_sequencerUpWithinGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        // answer = 0 means sequencer is up, but just came back up
        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Still within grace period, should return 0
        assertEq(l2Oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_sequencerUpAfterGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);

        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp past grace period
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Update price feeds to be fresh
        setBothPrices(100000e8, 100000e8);

        // Should return valid ratio now
        assertEq(l2Oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_sequencerUpExactlyAtGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);

        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp exactly to grace period (not past it)
        vm.warp(block.timestamp + GRACE_PERIOD);

        // Update price feeds
        setBothPrices(100000e8, 100000e8);

        // Should still return 0 (grace period not passed, need > not >=)
        assertEq(l2Oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_sequencerStartedAtZero() public {
        // On Arbitrum, startedAt returns 0 when Sequencer Uptime contract is not initialized
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : 0,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp past grace period
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Update price feeds to be fresh
        setBothPrices(100000e8, 100000e8);

        // Should return 0 when startedAt is 0 (not initialized)
        assertEq(l2Oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_sequencerDownAndStartedAtZero() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        // answer = 1 means sequencer is down and startedAt = 0 means feed contract not initialized
        sequencerFeed.setRoundData({
            _answer    : 1,
            _startedAt : 0,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp past grace period
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Update price feeds to be fresh
        setBothPrices(100000e8, 100000e8);

        // Should return 0 when answer != 0 and startedAt == 0
        assertEq(l2Oracle.latestAnswer(), 0);
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
        setCbbtcPrice(100000e8, staleTime, staleTime);

        // BTC feed is fresh
        setBtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_btcStalenessCheck(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, STALENESS_THRESHOLD_BTC + 1, 365 days);

        vm.warp(timeDelta + 1);

        uint256 staleTime = block.timestamp - timeDelta;
        setBtcPrice(100000e8, staleTime, staleTime);

        // cbBTC feed is fresh
        setCbbtcPrice(100000e8);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_sequencerGracePeriod(
        uint256 _gracePeriod,
        uint256 timePassed
    ) public {
        _gracePeriod = bound(_gracePeriod, 1, 24 hours);
        timePassed   = bound(timePassed,   0, _gracePeriod);

        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);

        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        CbBTCRatioOracle l2Oracle = new CbBTCRatioOracle(
            address(cbbtcUsdFeed),
            address(btcUsdFeed),
            STALENESS_THRESHOLD_CBBTC,
            STALENESS_THRESHOLD_BTC,
            address(sequencerFeed),
            _gracePeriod
        );

        vm.warp(block.timestamp + timePassed);

        // Price feeds always within grace period
        setBothPrices(100000e8, 100000e8);

        // If timePassed <= gracePeriod, should return 0
        assertEq(l2Oracle.latestAnswer(), 0);
    }

}
