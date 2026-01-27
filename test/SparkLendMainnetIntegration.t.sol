// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { IERC20 }    from "erc20-helpers/interfaces/IERC20.sol";
import { SafeERC20 } from "erc20-helpers/SafeERC20.sol";

import { IAaveOracle }                  from "sparklend-v1-core/interfaces/IAaveOracle.sol";
import { IPoolAddressesProvider }       from "sparklend-v1-core/interfaces/IPoolAddressesProvider.sol";
import { IPool }                        from "sparklend-v1-core/interfaces/IPool.sol";
import { IPoolConfigurator }            from "sparklend-v1-core/interfaces/IPoolConfigurator.sol";
import { IDefaultInterestRateStrategy } from "sparklend-v1-core/interfaces/IDefaultInterestRateStrategy.sol";

import { FixedPriceOracle }                   from "src/FixedPriceOracle.sol";
import { CappedFallbackRateSource }           from "src/CappedFallbackRateSource.sol";
import { CappedOracle }                       from "src/CappedOracle.sol";
import { SSRRateSource }                      from "src/SSRRateSource.sol";
import { RateTargetBaseInterestRateStrategy } from "src/RateTargetBaseInterestRateStrategy.sol";
import { RateTargetKinkInterestRateStrategy } from "src/RateTargetKinkInterestRateStrategy.sol";
import { RETHExchangeRateOracle }             from "src/RETHExchangeRateOracle.sol";
import { WSTETHExchangeRateOracle }           from "src/WSTETHExchangeRateOracle.sol";
import { WEETHExchangeRateOracle }            from "src/WEETHExchangeRateOracle.sol";
import { RSETHExchangeRateOracle }            from "src/RSETHExchangeRateOracle.sol";
import { EZETHExchangeRateOracle }            from "src/EZETHExchangeRateOracle.sol";
import { SPETHExchangeRateOracle }            from "src/SPETHExchangeRateOracle.sol";

interface ITollLike {
    function kiss(address) external;
}

// TODO: Add capped oracles for WBTC (need to import the combining contract first)
contract SparkLendMainnetIntegrationTest is Test {

    using SafeERC20 for IERC20;

    address AAVE_ORACLE             = 0x8105f69D9C41644c6A0803fDA7D03Aa70996cFD9;
    address POOL_ADDRESSES_PROVIDER = 0x02C3eA4e34C0cBd694D2adFa2c690EECbC1793eE;
    address POOL                    = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987;
    address POOL_CONFIGURATOR       = 0x542DBa469bdE58FAeE189ffB60C6b49CE60E0738;
    address ADMIN                   = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;  // SubDAO Proxy

    address DAI    = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address ETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC   = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT   = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address STETH  = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address RETH   = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address WEETH  = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address RSETH  = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address EZETH  = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address SUSDS  = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address SPETH  = 0xfE6eb3b609a7C8352A241f7F3A21CEA4e9209B8f;

    address ETH_IRM       = 0xD7A8461e6aF708a086D8285f8fD900309336347c;
    address USDC_ORACLE   = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address USDT_ORACLE   = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address USDC_USDT_IRM = 0xbc8A68B0ab0617D7c90d15bb1601B25d795Dc4c8;  // Note: This is the same for both because the parameters are the same
    address ETHUSD_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address RETH_ORACLE   = 0x05225Cd708bCa9253789C1374e4337a019e99D56;
    address WSTETH_ORACLE = 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93;
    address RSETH_ORACLE  = 0x349A73444b1a310BAe67ef67973022020d70020d;
    address EZETH_ORACLE  = 0x74a09653A083691711cF8215a6ab074BB4e99ef5;

    address LST_RATE_SOURCE = 0x08669C836F41AEaD03e3EF81a59f3b8e72EC417A;

    IAaveOracle            aaveOracle            = IAaveOracle(AAVE_ORACLE);
    IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER);
    IPool                  pool                  = IPool(POOL);
    IPoolConfigurator      configurator          = IPoolConfigurator(POOL_CONFIGURATOR);

    function setUp() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 19895484);  // May 18, 2024
    }

    function test_dai_market_oracle() public {
        // Set fork state to before this was introduced
        vm.createSelectFork(getChain("mainnet").rpcUrl, 18784436);  // Dec 14, 2023

        FixedPriceOracle oracle = new FixedPriceOracle(1e8);

        // Nothing is special about this number, it just happens to be the price at this block
        assertEq(aaveOracle.getAssetPrice(DAI), 0.99982058e8);

        address[] memory assets = new address[](1);
        assets[0] = DAI;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        assertEq(aaveOracle.getAssetPrice(DAI), 1e8);
    }

    function test_dai_market_irm() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 20965077);  // Oct 14, 2024

        RateTargetBaseInterestRateStrategy strategy
            = new RateTargetBaseInterestRateStrategy({
                provider:                      poolAddressesProvider,
                rateSource:                    address(new SSRRateSource(SUSDS)),
                optimalUsageRatio:             1e27,
                baseVariableBorrowRateSpread:  0,
                variableRateSlope1:            0,
                variableRateSlope2:            0
            });

        uint256 currentBorrowRate = 0.062930507342065968556080000e27;

        // Previous borrow rate
        assertEq(_getBorrowRate(DAI), currentBorrowRate);

        vm.prank(ADMIN);
        configurator.setReserveInterestRateStrategyAddress(
            DAI,
            address(strategy)
        );

        // Trigger an update from the new IRM
        _triggerUpdate(DAI);

        // Should be approximately unchanged because the spread is 1% lower which cancels the 1% higher SSR
        assertApproxEqRel(_getBorrowRate(DAI), currentBorrowRate, 0.001e18);

        // Change the borrow spread to 1%
        strategy = new RateTargetBaseInterestRateStrategy({
            provider:                     poolAddressesProvider,
            rateSource:                   address(new SSRRateSource(SUSDS)),
            optimalUsageRatio:            1e27,
            baseVariableBorrowRateSpread: 0.01e27,
            variableRateSlope1:           0,
            variableRateSlope2:           0
        });
        vm.prank(ADMIN);
        configurator.setReserveInterestRateStrategyAddress(
            DAI,
            address(strategy)
        );

        // Trigger an update from the new IRM
        _triggerUpdate(DAI);

        // Should be 1% higher than before
        assertApproxEqRel(_getBorrowRate(DAI), currentBorrowRate + 0.01e27, 0.001e18);
    }

    function test_eth_market_irm() public {
        CappedFallbackRateSource rateSource = new CappedFallbackRateSource({
            _source:      LST_RATE_SOURCE,
            _lowerBound:  0.01e18,
            _upperBound:  0.08e18,
            _defaultRate: 0.03e18
        });

        // Need to whitelist the rate source
        // Use a random authed address on the Chronicle oracle
        vm.prank(0xc50dFeDb7E93eF7A3DacCAd7987D0960c4e2CD4b);
        ITollLike(LST_RATE_SOURCE).kiss(address(rateSource));

        uint256 ethYield = 0.028485207053926554e27;  // 2.8% (approx APR as of May 18, 2024)
        uint256 spread   = 0.0015e27;                // 0.15%

        RateTargetKinkInterestRateStrategy strategy
            = new RateTargetKinkInterestRateStrategy({
                provider:                 poolAddressesProvider,
                rateSource:               address(rateSource),
                optimalUsageRatio:        0.9e27,
                baseVariableBorrowRate:   0,
                variableRateSlope1Spread: -int256(spread),
                variableRateSlope2:       1.2e27
            });
        IDefaultInterestRateStrategy prevStrategy
            = IDefaultInterestRateStrategy(ETH_IRM);

        _triggerUpdate(ETH);

        assertEq(strategy.getBaseVariableBorrowRate(),    prevStrategy.getBaseVariableBorrowRate());
        assertEq(prevStrategy.getVariableRateSlope1(),    0.028e27);
        assertEq(strategy.getVariableRateSlope1(),        ethYield - spread);
        assertEq(strategy.getVariableRateSlope2(),        prevStrategy.getVariableRateSlope2());
        assertEq(prevStrategy.getMaxVariableBorrowRate(), 1.228e27);
        assertEq(strategy.getMaxVariableBorrowRate(),     1.2e27 + ethYield - spread);

        _triggerUpdate(ETH);

        assertEq(_getBorrowRate(ETH), 0.017624470144971981744160716e27);

        vm.prank(ADMIN);
        configurator.setReserveInterestRateStrategyAddress(
            ETH,
            address(strategy)
        );

        _triggerUpdate(ETH);

        // slope1 has adjusted down a bit so the borrow rate is slightly lower at same utilization
        assertEq(_getBorrowRate(ETH), 0.016985713431350567055736333e27);
    }

    function test_usdc_usdt_market_oracles() public {
        // Set fork state to before this was introduced
        vm.createSelectFork(getChain("mainnet").rpcUrl, 18784436);  // Dec 14, 2023

        CappedOracle usdcOracle = new CappedOracle(USDC_ORACLE, 1e8);
        CappedOracle usdtOracle = new CappedOracle(USDT_ORACLE, 1e8);

        // Nothing is special about these numbers, they just happen to be the price at this block
        assertEq(aaveOracle.getAssetPrice(USDC), 1.00005299e8);
        assertEq(aaveOracle.getAssetPrice(USDT), 0.99961441e8);

        address[] memory assets = new address[](2);
        assets[0] = USDC;
        assets[1] = USDT;
        address[] memory sources = new address[](2);
        sources[0] = address(usdcOracle);
        sources[1] = address(usdtOracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        assertEq(aaveOracle.getAssetPrice(USDC), 1e8);
        assertEq(aaveOracle.getAssetPrice(USDT), 0.99961441e8);
    }

    function test_usdc_usdt_market_irms() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 20965077);  // Oct 14, 2024

        RateTargetKinkInterestRateStrategy strategy
            = new RateTargetKinkInterestRateStrategy({
                provider:                 poolAddressesProvider,
                rateSource:               address(new SSRRateSource(SUSDS)),
                optimalUsageRatio:        0.95e27,
                baseVariableBorrowRate:   0,
                variableRateSlope1Spread: 0.01e27,  // 1% spread
                variableRateSlope2:       0.2e27
            });

        _triggerUpdate(USDC);
        _triggerUpdate(USDT);

        uint256 currentRateUSDC = 0.207489689165388369527167411e27;
        uint256 currentRateUSDT = 0.057737691380706874411856558e27;

        assertEq(_getBorrowRate(USDC), currentRateUSDC, "before: USDC mismatch");
        assertEq(_getBorrowRate(USDT), currentRateUSDT, "before: USDT mismatch");

        vm.startPrank(ADMIN);
        configurator.setReserveInterestRateStrategyAddress(
            USDC,
            address(strategy)
        );
        configurator.setReserveInterestRateStrategyAddress(
            USDT,
            address(strategy)
        );
        vm.stopPrank();

        _triggerUpdate(USDC);
        _triggerUpdate(USDT);

        // Rates will change due to SSR being 1% higher than DSR
        // The 1% APR change will result in a much higher jump for USDC which is already at ~20% APY
        uint256 newRateUSDC = 0.264906695480144435148836548e27;
        uint256 newRateUSDT = 0.066310128707421710970337545e27;

        assertEq(_getBorrowRate(USDC), newRateUSDC, "after1: USDC mismatch");
        assertEq(_getBorrowRate(USDT), newRateUSDT, "after1: USDT mismatch");
    }

    function test_reth_market_oracle() public {
        // Set fork state to before this was introduced
        vm.createSelectFork(getChain("mainnet").rpcUrl, 19015252);  // Jan 15, 2024

        RETHExchangeRateOracle oracle = new RETHExchangeRateOracle(RETH, ETHUSD_ORACLE);

        // Nothing is special about this number, it just happens to be the price at this block
        uint256 beforePrice = 2747.09479896e8;
        assertEq(aaveOracle.getAssetPrice(RETH),    beforePrice);
        assertEq(aaveOracle.getSourceOfAsset(RETH), RETH_ORACLE);

        address[] memory assets = new address[](1);
        assets[0] = RETH;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        assertEq(aaveOracle.getAssetPrice(RETH),    beforePrice);
        assertEq(aaveOracle.getSourceOfAsset(RETH), address(oracle));
    }

    function test_wsteth_market_oracle() public {
        // Set fork state to before this was introduced
        vm.createSelectFork(getChain("mainnet").rpcUrl, 19015252);  // Jan 15, 2024

        WSTETHExchangeRateOracle oracle = new WSTETHExchangeRateOracle(STETH, ETHUSD_ORACLE);

        // Nothing is special about this number, it just happens to be the price at this block
        uint256 beforePrice = 2893.26746079e8;
        assertEq(aaveOracle.getAssetPrice(WSTETH),    beforePrice);
        assertEq(aaveOracle.getSourceOfAsset(WSTETH), WSTETH_ORACLE);

        address[] memory assets = new address[](1);
        assets[0] = WSTETH;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        assertEq(aaveOracle.getAssetPrice(WSTETH),    beforePrice);
        assertEq(aaveOracle.getSourceOfAsset(WSTETH), address(oracle));
    }

    function test_weeth_market_oracle() public {
        WEETHExchangeRateOracle oracle = new WEETHExchangeRateOracle(WEETH, ETHUSD_ORACLE);

        vm.expectRevert();  // Not setup yet
        assertEq(aaveOracle.getAssetPrice(WEETH),    0);
        assertEq(aaveOracle.getSourceOfAsset(WEETH), address(0));

        address[] memory assets = new address[](1);
        assets[0] = WEETH;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        // Nothing is special about this number, it just happens to be the price at this block
        uint256 price = 3225.32665359e8;

        assertEq(aaveOracle.getAssetPrice(WEETH),    price);
        assertEq(aaveOracle.getSourceOfAsset(WEETH), address(oracle));
    }

    function test_rseth_market_oracle() public {
        RSETHExchangeRateOracle oracle = new RSETHExchangeRateOracle(RSETH_ORACLE, ETHUSD_ORACLE);

        vm.expectRevert();  // Not setup yet
        assertEq(aaveOracle.getAssetPrice(RSETH),    0);
        assertEq(aaveOracle.getSourceOfAsset(RSETH), address(0));

        address[] memory assets = new address[](1);
        assets[0] = RSETH;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        // Nothing is special about this number, it just happens to be the price at this block
        uint256 price = 3144.93204796e8;

        assertEq(aaveOracle.getAssetPrice(RSETH),    price);
        assertEq(aaveOracle.getSourceOfAsset(RSETH), address(oracle));
    }

    function test_ezeth_market_oracle() public {
        EZETHExchangeRateOracle oracle = new EZETHExchangeRateOracle(EZETH_ORACLE, ETHUSD_ORACLE);

        vm.expectRevert();  // Not setup yet
        assertEq(aaveOracle.getAssetPrice(EZETH),    0);
        assertEq(aaveOracle.getSourceOfAsset(EZETH), address(0));

        address[] memory assets = new address[](1);
        assets[0] = EZETH;
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        // Nothing is special about this number, it just happens to be the price at this block
        uint256 price = 3135.93175044e8;

        assertEq(aaveOracle.getAssetPrice(EZETH),    price);
        assertEq(aaveOracle.getSourceOfAsset(EZETH), address(oracle));
    }

    function test_speth_market_oracle() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl, 24318543);  // Jan 26, 2026

        SPETHExchangeRateOracle oracle = new SPETHExchangeRateOracle(SPETH, ETHUSD_ORACLE);

        vm.expectRevert(); // SPETH not yet added on SparkLend
        assertEq(aaveOracle.getAssetPrice(SPETH),    0);
        assertEq(aaveOracle.getSourceOfAsset(SPETH), address(0));

        address[] memory assets = new address[](1);
        assets[0] = SPETH;

        address[] memory sources = new address[](1);
        sources[0] = address(oracle);

        vm.prank(ADMIN);
        aaveOracle.setAssetSources(
            assets,
            sources
        );

        // spETH Price (USD) at this block
        uint256 price = 2904.01656577e8;

        assertEq(aaveOracle.getAssetPrice(SPETH),    price);
        assertEq(aaveOracle.getSourceOfAsset(SPETH), address(oracle));
    }

    /**********************************************************************************************/
    /*** Helper Functions                                                                       ***/
    /**********************************************************************************************/

    function _getBorrowRate(address asset) internal view returns (uint256) {
        return pool.getReserveData(asset).currentVariableBorrowRate;
    }

    function _triggerUpdate(address asset) internal {
        // Flashloan small amount to force indices update
        pool.flashLoanSimple(address(this), asset, 1, "", 0);
    }

    // Flashloan callback
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        address,
        bytes calldata
    ) external returns (bool) {
        IERC20(asset).safeApprove(msg.sender, amount + fee);
        return true;
    }

}
