// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { AggregatorV3Mock } from "./mocks/AggregatorV3Mock.sol";

import { RETHRatioOracle } from "../src/RETHRatioOracle.sol";

contract RETHMock {

    uint256 exchangeRate;

    constructor(uint256 _exchangeRate) {
        exchangeRate = _exchangeRate;
    }

    function getExchangeRate() external view returns (uint256) {
        return exchangeRate;
    }

    function setExchangeRate(uint256 _exchangeRate) external {
        exchangeRate = _exchangeRate;
    }

}

contract RETHRatioOracleTest is Test {

    RETHMock         reth;
    AggregatorV3Mock rethEthFeed;

    RETHRatioOracle oracle;

    uint256 constant STALENESS_THRESHOLD = 1 days;

    function setUp() public {
        reth        = new RETHMock(1.05e18);
        rethEthFeed = new AggregatorV3Mock(18);

        // Set valid Chainlink data: rETH/ETH = 1.05e18
        setRethPrice(1.05e18);

        oracle = new RETHRatioOracle(
            address(reth),
            address(rethEthFeed),
            STALENESS_THRESHOLD
        );
    }

    /**********************************************************************************************/
    /*** Test Helpers                                                                           ***/
    /**********************************************************************************************/

    /// @dev Sets rETH price feed with custom updatedAt timestamp
    function setRethPrice(int256 price, uint256 updatedAt) internal {
        rethEthFeed.setRoundData({
            _answer    : price,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets rETH price feed with current block.timestamp
    function setRethPrice(int256 price) internal {
        setRethPrice(price, block.timestamp);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.reth()),        address(reth));
        assertEq(address(oracle.rethEthFeed()), address(rethEthFeed));
        assertEq(oracle.stalenessThreshold(),   STALENESS_THRESHOLD);
    }

    function test_constructor_invalidFeedDecimals() public {
        rethEthFeed.setDecimals(8);

        vm.expectRevert("RETHRatioOracle/invalid-feed-decimals");
        new RETHRatioOracle(
            address(reth),
            address(rethEthFeed),
            STALENESS_THRESHOLD
        );
    }

    function test_constructor_invalidStalenessZero() public {
        vm.expectRevert("RETHRatioOracle/invalid-staleness");
        new RETHRatioOracle(
            address(reth),
            address(rethEthFeed),
            0
        );
    }

    /**********************************************************************************************/
    /*** latestAnswer Tests                                                                     ***/
    /**********************************************************************************************/

    function test_latestAnswer_perfectPeg() public {
        // rETH/ETH price = 1.05e18, rETH exchange rate = 1.05e18
        // rETH/ETH ratio = 1.05e18 * 1e18 / 1.05e18 = 1e18 
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_depeg() public {
        // rETH/ETH price = 1.0e18 (market), rETH exchange rate = 1.05e18 
        // rETH/ETH ratio = 1.0e18 * 1e18 / 1.05e18 = 952380952380952380 (discount)
        rethEthFeed.setAnswer(1.0e18);
        assertEq(oracle.latestAnswer(), 0.952380952380952380e18);
    }

    function test_latestAnswer_premium() public {
        // rETH/ETH price = 1.1e18 (market), rETH exchange rate = 1.05e18 
        // rETH/ETH ratio = 1.1e18 * 1e18 / 1.05e18 = ~1.0476e18 (premium)
        rethEthFeed.setAnswer(1.1e18);
        assertEq(oracle.latestAnswer(), 1.047619047619047619e18);
    }

    function test_latestAnswer_zeroPrice() public {
        rethEthFeed.setAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativePrice() public {
        rethEthFeed.setAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroRate() public {
        reth.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Chainlink Staleness Tests                                                              ***/
    /**********************************************************************************************/

    function test_latestAnswer_stalePrice() public {
        setRethPrice(1.05e18);

        vm.warp(block.timestamp + STALENESS_THRESHOLD + 1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_priceAtThreshold() public {
        setRethPrice(1.05e18);

        vm.warp(block.timestamp + STALENESS_THRESHOLD);
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_updatedAtZero() public {
        setRethPrice(1.05e18, 0);

        assertEq(oracle.latestAnswer(), 0);
    }

    /**********************************************************************************************/
    /*** Fuzz Tests                                                                             ***/
    /**********************************************************************************************/

    function testFuzz_latestAnswer_ratioCalculation(
        uint256 rethEthPrice,
        uint256 rethRate
    ) public {
        // Bound to realistic ranges to avoid overflow
        rethEthPrice = bound(rethEthPrice, 1, 100e18);
        rethRate     = bound(rethRate,     1, 100e18);

        reth.setExchangeRate(rethRate);
        rethEthFeed.setAnswer(int256(rethEthPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((rethEthPrice * 1e18) / rethRate);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 value) public {
        // When price equals rate, ratio should be 1e18
        value = bound(value, 1, 100e18);

        reth.setExchangeRate(value);
        rethEthFeed.setAnswer(int256(value));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidPrice(int256 price) public {
        // Any non-positive price should return 0
        price = bound(price, type(int256).min, 0);
        rethEthFeed.setAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnZeroRate(uint256 rethEthPrice) public {
        rethEthPrice = bound(rethEthPrice, 1, 100e18);
        rethEthFeed.setAnswer(int256(rethEthPrice));
        reth.setExchangeRate(0);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_stalenessCheck(uint256 timeDelta) public {
        timeDelta = bound(timeDelta, STALENESS_THRESHOLD + 1, 365 days);

        vm.warp(timeDelta + 1);

        uint256 staleTime = block.timestamp - timeDelta;
        setRethPrice(1.05e18, staleTime);

        assertEq(oracle.latestAnswer(), 0);
    }

}
