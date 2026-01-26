// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { SPETHExchangeRateOracle } from "../src/SPETHExchangeRateOracle.sol";

contract SPETHMock {

    uint256 exchangeRate;

    constructor(uint256 _exchangeRate) {
        exchangeRate = _exchangeRate;
    }

    function convertToAssets(uint256 shares) external view returns (uint256) {
        return exchangeRate * shares / 1e18;
    }

    function setExchangeRate(uint256 _exchangeRate) external {
        exchangeRate = _exchangeRate;
    }

}

contract SPETHExchangeRateOracleTest is Test {

    SPETHMock       speth;
    PriceSourceMock ethSource;

    SPETHExchangeRateOracle oracle;

    function setUp() public {
        speth     = new SPETHMock(1.0036e18);
        ethSource = new PriceSourceMock(2000e8, 8);
        oracle    = new SPETHExchangeRateOracle(address(speth), address(ethSource));
    }

    function test_constructor() public {
        assertEq(address(oracle.speth()),     address(speth));
        assertEq(address(oracle.ethSource()), address(ethSource));
        assertEq(oracle.decimals(),           8);
    }

    function test_invalid_decimals() public {
        ethSource.setLatestAnswer(2000e18);
        ethSource.setDecimals(18);
        vm.expectRevert("SPETHExchangeRateOracle/invalid-decimals");
        new SPETHExchangeRateOracle(address(speth), address(ethSource));
    }

    function test_latestAnswer_zeroEthUsd() public {
        ethSource.setLatestAnswer(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_negativeEthUsd() public {
        ethSource.setLatestAnswer(-1);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer_zeroExchangeRate() public {
        speth.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer() public {
        // 1.0036 * 2000 = 2007.2
        assertEq(oracle.latestAnswer(), 2007.2e8);

        // 1 * 2000 = 2000
        speth.setExchangeRate(1e18);
        assertEq(oracle.latestAnswer(), 2000e8);

        // 1 * 3000 = 3000
        ethSource.setLatestAnswer(3000e8);
        assertEq(oracle.latestAnswer(), 3000e8);

        // 1.1 * 2500 = 2750
        speth.setExchangeRate(1.1e18);
        ethSource.setLatestAnswer(2500e8);
        assertEq(oracle.latestAnswer(), 2750e8);
    }

    function testFuzz_latestAnswer(uint256 exchangeRate, uint256 ethPrice) public {
        // Bound exchange rate between 1.0 and 2.0 (reasonable LST range)
        exchangeRate = bound(exchangeRate, 1e18, 2e18);
        // Bound ETH price between $100 and $100,000
        ethPrice = bound(ethPrice, 100e8, 100_000e8);

        speth.setExchangeRate(exchangeRate);
        ethSource.setLatestAnswer(int256(ethPrice));

        int256 result = oracle.latestAnswer();
        int256 expected = int256(exchangeRate) * int256(ethPrice) / 1e18;

        assertEq(result, expected);
    }

}
