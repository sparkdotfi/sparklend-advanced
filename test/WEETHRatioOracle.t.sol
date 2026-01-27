// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { AggregatorV3Mock } from "./mocks/AggregatorV3Mock.sol";

import { WEETHRatioOracle } from "../src/WEETHRatioOracle.sol";

contract WEETHMock {

    uint256 exchangeRate;

    constructor(uint256 _exchangeRate) {
        exchangeRate = _exchangeRate;
    }

    function getRate() external view returns (uint256) {
        return exchangeRate;
    }

    function setExchangeRate(uint256 _exchangeRate) external {
        exchangeRate = _exchangeRate;
    }

}

contract WEETHRatioOracleTest is Test {

    WEETHMock        weeth;
    AggregatorV3Mock weethEthFeed;

    WEETHRatioOracle oracle;

    uint256 constant STALENESS_THRESHOLD = 1 days;
    uint256 constant GRACE_PERIOD        = 1 hours;

    function setUp() public {
        weeth        = new WEETHMock(1.05e18);
        weethEthFeed = new AggregatorV3Mock(18);

        // Set valid Chainlink data: weETH/ETH = 1.05e18
        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        // Deploy without sequencer feed (L1 mode)
        oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(0),
            0
        );
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.weeth()),               address(weeth));
        assertEq(address(oracle.weethEthFeed()),        address(weethEthFeed));
        assertEq(oracle.stalenessThreshold(),           STALENESS_THRESHOLD);
        assertEq(address(oracle.sequencerUptimeFeed()), address(0));
        assertEq(oracle.gracePeriod(),                  0);
    }

    function test_constructor_withSequencerFeed() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        assertEq(address(l2Oracle.sequencerUptimeFeed()), address(sequencerFeed));
        assertEq(l2Oracle.gracePeriod(),                  GRACE_PERIOD);
    }

    function test_constructor_invalidFeedDecimals() public {
        weethEthFeed.setDecimals(8);

        vm.expectRevert("WEETHRatioOracle/invalid-feed-decimals");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(0),
            0
        );
    }

    function test_constructor_invalidStalenessZero() public {
        vm.expectRevert("WEETHRatioOracle/invalid-staleness");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            0,
            address(0),
            0
        );
    }

    function test_constructor_invalidSequencerConfig_gracePeriodWithoutFeed() public {
        vm.expectRevert("WEETHRatioOracle/invalid-sequencer-config");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
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

        vm.expectRevert("WEETHRatioOracle/invalid-sequencer-config");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            0
        );
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() public {
        // weETH/ETH price = 1.05e18, weETH rate = 1.05e18
        // eETH/ETH ratio = 1.05e18 * 1e18 / 1.05e18 = 1e18 (perfect peg)
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() public {
        // weETH/ETH price = 1.0e18 (market), weETH rate = 1.05e18 (exchange rate)
        // eETH/ETH ratio = 1.0e18 * 1e18 / 1.05e18 = 952380952380952380 (depegged)
        weethEthFeed.setAnswer(1.0e18);
        assertEq(oracle.latestAnswer(), 0.952380952380952380e18);
    }

    function test_latestAnswer_premium() public {
        // weETH/ETH price = 1.1e18 (market), weETH rate = 1.05e18 (exchange rate)
        // eETH/ETH ratio = 1.1e18 * 1e18 / 1.05e18 = ~1.0476e18 (premium)
        weethEthFeed.setAnswer(1.1e18);
        assertEq(oracle.latestAnswer(), 1.047619047619047619e18);
    }

    function test_latestAnswer_zeroPrice() public {
        weethEthFeed.setAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativePrice() public {
        weethEthFeed.setAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroRate() public {
        weeth.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Chainlink Staleness Tests                                                              ***/
    /**********************************************************************************************/

    function test_latestAnswer_stalePrice() public {
        uint256 updatedAt = block.timestamp;

        vm.warp(block.timestamp + STALENESS_THRESHOLD + 1);

        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : updatedAt,
            _updatedAt : updatedAt
        });

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_priceAtThreshold() public {
        uint256 updatedAt = block.timestamp;

        vm.warp(block.timestamp + STALENESS_THRESHOLD);

        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : updatedAt,
            _updatedAt : updatedAt
        });

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_updatedAtZero() public {
        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : 0,
            _updatedAt : 0
        });

        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_works_StartedAtZero() public {
        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : 0,
            _updatedAt : block.timestamp
        });

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

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
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

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Still within grace period, should return 0
        assertEq(l2Oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_sequencerUpAfterGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        uint256 sequencerStartedAt = block.timestamp;

        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : sequencerStartedAt,
            _updatedAt : block.timestamp
        });

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp past grace period
        vm.warp(block.timestamp + GRACE_PERIOD + 1);

        // Update price feed to be fresh
        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

        // Should return valid ratio now
        assertEq(l2Oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_sequencerUpExactlyAtGracePeriod() public {
        AggregatorV3Mock sequencerFeed = new AggregatorV3Mock(0);
        uint256 sequencerStartedAt = block.timestamp;

        sequencerFeed.setRoundData({
            _answer    : 0,
            _startedAt : sequencerStartedAt,
            _updatedAt : block.timestamp
        });

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Warp exactly to grace period (not past it)
        vm.warp(block.timestamp + GRACE_PERIOD);

        // Update price feed
        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp
        });

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

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            GRACE_PERIOD
        );

        // Should return 0 when startedAt is 0 (not initialized)
        assertEq(l2Oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 weethEthPrice,
        uint256 weethRate
    ) public {
        // Bound to realistic ranges to avoid overflow
        weethEthPrice = bound(weethEthPrice, 1, 100e18);
        weethRate     = bound(weethRate,     1, 100e18);

        weeth.setExchangeRate(weethRate);
        weethEthFeed.setAnswer(int256(weethEthPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((weethEthPrice * 1e18) / weethRate);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 value) public {
        // When price equals rate, ratio should be 1e18
        value = bound(value, 1, 100e18);

        weeth.setExchangeRate(value);
        weethEthFeed.setAnswer(int256(value));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidPrice(int256 price) public {
        // Any non-positive price should return 0
        price = bound(price, type(int256).min, 0);
        weethEthFeed.setAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnZeroRate(uint256 weethEthPrice) public {
        weethEthPrice = bound(weethEthPrice, 1, 100e18);
        weethEthFeed.setAnswer(int256(weethEthPrice));
        weeth.setExchangeRate(0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_stalenessCheck(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, STALENESS_THRESHOLD + 1, 365 days);
        
        vm.warp(timeDelta+ 1);

        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : block.timestamp - timeDelta,
            _updatedAt : block.timestamp - timeDelta 
        });

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

        WEETHRatioOracle l2Oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD,
            address(sequencerFeed),
            _gracePeriod
        );

        vm.warp(block.timestamp + timePassed); 

        weethEthFeed.setRoundData({
            _answer    : 1.05e18,
            _startedAt : block.timestamp,
            _updatedAt : block.timestamp // always within _gracePeriod
        });

        // If timePassed <= gracePeriod, should return 0
        assertEq(l2Oracle.latestAnswer(), 0);
    }

}
