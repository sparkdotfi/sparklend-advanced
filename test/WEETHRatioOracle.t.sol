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

    function setUp() public {
        weeth        = new WEETHMock(1.05e18);
        weethEthFeed = new AggregatorV3Mock(18);

        // Set valid Chainlink data: weETH/ETH = 1.05e18
        setWeethPrice(1.05e18);

        oracle = new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD
        );
    }

    /**********************************************************************************************/
    /*** Test Helpers                                                                           ***/
    /**********************************************************************************************/

    /// @dev Sets weETH price feed with custom updatedAt timestamp
    function setWeethPrice(int256 price, uint256 updatedAt) internal {
        weethEthFeed.setRoundData({
            _answer    : price,
            _updatedAt : updatedAt
        });
    }

    /// @dev Sets weETH price feed with current block.timestamp
    function setWeethPrice(int256 price) internal {
        setWeethPrice(price, block.timestamp);
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.weeth()),               address(weeth));
        assertEq(address(oracle.weethEthFeed()),        address(weethEthFeed));
        assertEq(oracle.stalenessThreshold(),           STALENESS_THRESHOLD);
    }

    function test_constructor_invalidFeedDecimals() public {
        weethEthFeed.setDecimals(8);

        vm.expectRevert("WEETHRatioOracle/invalid-feed-decimals");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
            STALENESS_THRESHOLD
        );
    }

    function test_constructor_invalidStalenessZero() public {
        vm.expectRevert("WEETHRatioOracle/invalid-staleness");
        new WEETHRatioOracle(
            address(weeth),
            address(weethEthFeed),
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
        setWeethPrice(1.05e18);

        vm.warp(block.timestamp + STALENESS_THRESHOLD + 1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_priceAtThreshold() public {
        setWeethPrice(1.05e18);

        vm.warp(block.timestamp + STALENESS_THRESHOLD);
        assertEq(oracle.latestAnswer(), 1e18);
    }

    function test_latestAnswer_updatedAtZero() public {
        setWeethPrice(1.05e18, 0);

        assertEq(oracle.latestAnswer(), 0);
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

        vm.warp(timeDelta + 1);

        uint256 staleTime = block.timestamp - timeDelta;
        setWeethPrice(1.05e18, staleTime);

        assertEq(oracle.latestAnswer(), 0);
    }

}
