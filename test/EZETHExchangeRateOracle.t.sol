// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { PriceSourceMock } from "./mocks/PriceSourceMock.sol";

import { EZETHExchangeRateOracle } from "../src/EZETHExchangeRateOracle.sol";

// This can be both the oracle and the ezETH token for the purposes of this unit testing contract
contract EZETHOracleMock {

    uint256 exchangeRate;

    constructor(uint256 _exchangeRate) {
        exchangeRate = _exchangeRate;
    }

    function calculateTVLs() external view returns (uint256[][] memory , uint256[] memory, uint256 _exchangeRate) {
        _exchangeRate = exchangeRate;
    }

    function totalSupply() external pure returns (uint256) {
        return 1e18;
    }

    function ezETH() external view returns (address) {
        return address(this);
    }

    function setExchangeRate(uint256 _exchangeRate) external {
        exchangeRate = _exchangeRate;
    }

}

contract EZETHExchangeRateOracleTest is Test {

    EZETHOracleMock ezethOracle;
    PriceSourceMock ethSource;

    EZETHExchangeRateOracle oracle;

    function setUp() public {
        ezethOracle = new EZETHOracleMock(1.2e18);
        ethSource   = new PriceSourceMock(2000e8, 8);
        oracle      = new EZETHExchangeRateOracle(address(ezethOracle), address(ethSource));
    }

    function test_constructor() public {
        assertEq(address(oracle.oracle()),    address(ezethOracle));
        assertEq(address(oracle.ethSource()), address(ethSource));
        assertEq(oracle.decimals(),           8);
    }

    function test_invalid_decimals() public {
        ethSource.setLatestAnswer(2000e18);
        ethSource.setDecimals(18);
        vm.expectRevert("EZETHExchangeRateOracle/invalid-decimals");
        new EZETHExchangeRateOracle(address(ezethOracle), address(ethSource));
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
        ezethOracle.setExchangeRate(0);
        assertEq(oracle.latestAnswer(), 0);
    }

    function test_latestAnswer() public {
        // 1.2 * 2000 = 2400
        assertEq(oracle.latestAnswer(), 2400e8);

        // 1 * 2000 = 2000
        ezethOracle.setExchangeRate(1e18);
        assertEq(oracle.latestAnswer(), 2000e8);

        // 0.5 * 1200 = 600
        ezethOracle.setExchangeRate(0.5e18);
        ethSource.setLatestAnswer(1200e8);
        assertEq(oracle.latestAnswer(), 600e8);
    }

}
