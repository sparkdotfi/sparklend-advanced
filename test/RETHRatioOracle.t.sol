// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

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
    PriceSourceMock  rethEthFeed;

    RETHRatioOracle oracle;

    function setUp() public {
        reth        = new RETHMock(1.05e18);
        rethEthFeed = new PriceSourceMock(1.05e18, 18);

        oracle = new RETHRatioOracle(
            address(reth),
            address(rethEthFeed)
        );
    }

    /**********************************************************************************************/
    /*** Constructor Tests                                                                      ***/
    /**********************************************************************************************/

    function test_constructor() public {
        assertEq(address(oracle.reth()),        address(reth));
        assertEq(address(oracle.rethEthFeed()), address(rethEthFeed));
    }

    function test_constructor_invalidFeedDecimals() public {
        rethEthFeed.setDecimals(8);

        vm.expectRevert("RETHRatioOracle/invalid-feed-decimals");
        new RETHRatioOracle(
            address(reth),
            address(rethEthFeed)
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
        rethEthFeed.setLatestAnswer(1.0e18);
        assertEq(oracle.latestAnswer(), 0.952380952380952380e18);
    }

    function test_latestAnswer_premium() public {
        // rETH/ETH price = 1.1e18 (market), rETH exchange rate = 1.05e18 
        // rETH/ETH ratio = 1.1e18 * 1e18 / 1.05e18 = ~1.0476e18 (premium)
        rethEthFeed.setLatestAnswer(1.1e18);
        assertEq(oracle.latestAnswer(), 1.047619047619047619e18);
    }

    function test_latestAnswer_zeroPrice() public {
        rethEthFeed.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativePrice() public {
        rethEthFeed.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroRate() public {
        reth.setExchangeRate(0);
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
        rethEthFeed.setLatestAnswer(int256(rethEthPrice));

        int256 ratio    = oracle.latestAnswer();
        int256 expected = int256((rethEthPrice * 1e18) / rethRate);

        assertEq(ratio, expected);
    }

    function testFuzz_latestAnswer_perfectPeg(uint256 value) public {
        // When price equals rate, ratio should be 1e18
        value = bound(value, 1, 100e18);

        reth.setExchangeRate(value);
        rethEthFeed.setLatestAnswer(int256(value));

        assertEq(oracle.latestAnswer(), 1e18);
    }

    function testFuzz_latestAnswer_zeroOnInvalidPrice(int256 price) public {
        // Any non-positive price should return 0
        price = bound(price, type(int256).min, 0);
        rethEthFeed.setLatestAnswer(price);

        assertEq(oracle.latestAnswer(), 0);
    }

    function testFuzz_latestAnswer_zeroOnZeroRate(uint256 rethEthPrice) public {
        rethEthPrice = bound(rethEthPrice, 1, 100e18);
        rethEthFeed.setLatestAnswer(int256(rethEthPrice));
        reth.setExchangeRate(0);

        assertEq(oracle.latestAnswer(), 0);
    }

}
