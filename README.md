# SparkLend Advanced Contracts

This repository contains advanced features to improve SparkLend beyond the core contracts. This repository is mostly focused on improving security and automating governance processes.

## Available Contracts

### Oracles

Please note all these oracles are designed for consumption by `AaveOracle` which assumes 8 decimal places.

[FixedPriceOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/FixedPriceOracle.sol): A hardcoded oracle price that never changes. Used for: DAI/USDC/USDT markets

[CappedOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/CappedOracle.sol): Returns `min(market price, hardcoded max price)`. Not currently used.

[WSTETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/WSTETHExchangeRateOracle.sol): Provides wstETH/USD by multiplying the wstETH exchange rate by ETH/USD. Used for: wstETH market

[RETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/RETHExchangeRateOracle.sol): Provides rETH/USD by multiplying the rETH exchange rate by ETH/USD. Used for: rETH market

[WEETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/WEETHExchangeRateOracle.sol): Provides weETH/USD by multiplying the weETH exchange rate by ETH/USD. Used for: weETH market

[RSETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/RSETHExchangeRateOracle.sol): Provides rsETH/USD by multiplying the rsETH exchange rate by ETH/USD. Used for: rsETH market

[EZETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/EZETHExchangeRateOracle.sol): Provides ezETH/USD by multiplying the ezETH exchange rate by ETH/USD. Used for: ezETH market

[SPETHExchangeRateOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/SPETHExchangeRateOracle.sol): Provides spETH/USD by multiplying the spETH (ERC-4626) exchange rate by ETH/USD. Used for: spETH market

[WEETHRatioOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/WEETHRatioOracle.sol): Provides eETH/ETH by dividing the weETH/ETH price by the weETH exchange rate. Used for: KillSwitch monitoring

[MorphoUpgradableOracle](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/MorphoUpgradableOracle.sol): Allows Spark Governance to change an oracle for Morpho Blue markets. Planned to be used in Morpho Blue.

### Custom Interest Rate Strategies

[VariableBorrowInterestRateStrategy](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/VariableBorrowInterestRateStrategy.sol): Modified version of `DefaultReserveInterestRateStrategy` that removes the stable borrow logic.

[RateTargetBaseInterestRateStrategy](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/RateTargetBaseInterestRateStrategy.sol): Overridden version of `VariableBorrowInterestRateStrategy` that sets the base variable borrow rate to match an external rate source with a fixed spread. Used for: DAI market

[RateTargetKinkInterestRateStrategy](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/RateTargetKinkInterestRateStrategy.sol): Overridden version of `VariableBorrowInterestRateStrategy` that sets the variable slope 1 rate to match an external rate source with a fixed spread. Used for: ETH/USDC/USDT markets

### Rate Sources

[PotRateSource](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/PotRateSource.sol): Adapter to convert DSR into APR which can be consumed by one of the rate target interest rate strategies. Used for: DAI/USDC/USDT markets

[CappedFallbackRateSource](https://github.com/marsfoundation/sparklend-advanced/blob/master/src/CappedFallbackRateSource.sol): Wraps another rate source, caps the rate and protects against reverts with a fallback value. Used for: ETH market

## Usage

```bash
forge build
```

## Test

```bash
forge test
```
