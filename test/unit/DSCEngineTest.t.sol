// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console2} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC public deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public engine;
    HelperConfig public config;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant DSC_MINT_AMOUNT = 100 ether; //100$ worth

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);
    }

    //////////////////////////
    /// Price Tests ///
    //////////////////////////
    function testGetUsdValue() public {
        // Arrange
        uint256 amount = 15 ether; // 15 WETH
        // 15 WETH * $2000/WETH = $30,000
        uint256 expectedUsdValue = 30000 ether; // Should be 30,000e18

        // Act
        uint256 actualUsdValue = engine.getUsdValue(weth, amount);

        // Assert
        assertEq(actualUsdValue, expectedUsdValue);
    }

    function testGetTokenAmountFromUsd() public {
        // Arrange
        uint256 usdAmount = 100 ether; // $100
        // $100 / $2000/WETH = 0.05 WETH
        uint256 expectedWethAmount = 0.05 ether;

        // Act
        uint256 actualWethAmount = engine.getTokenAmountFromUsd(weth, usdAmount);

        // Assert
        assertEq(actualWethAmount, expectedWethAmount);
    }

    //////////////////////////
    /// Constructor Tests ///
    //////////////////////////
    function testRevertsIfTokenAddressesAndPriceFeedAddressesLengthDontMatch() public {
        // This test needs its own deployment setup
        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = weth;

        address[] memory priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = ethUsdPriceFeed;
        priceFeedAddresses[1] = btcUsdPriceFeed;

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testGetsTokenAddress() public view {
        address[] memory s_collateralTokens = engine.getCollateralTokens();
        assertEq(s_collateralTokens[0], weth);
        assertEq(s_collateralTokens[1], wbtc);
    }

    //////////////////////////////
    // Deposit Collateral Tests //
    //////////////////////////////
    function testRevertsIfCollateralAmountIsZero() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Act & Assert: We expect the transaction to revert with our custom error.
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        // Arrange: Create a new, random ERC20 token that is not registered with the DSCEngine.
        ERC20Mock randToken = new ERC20Mock("RAND", "RAND", USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        randToken.approve(address(engine), STARTING_ERC20_BALANCE);

        // Act & Assert: We expect the transaction to revert, specifying that the token is not allowed.
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(randToken)));
        engine.depositCollateral(address(randToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateral() public {
        // Arrange: The user must first approve the DSCEngine contract to spend their WETH.
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        // Act: The user calls depositCollateral.
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // Assert: The engine's record of the user's deposited collateral should match the deposited amount.
        uint256 collateralDeposited = engine.getCollateralDeposited(USER, weth);
        assertEq(collateralDeposited, AMOUNT_COLLATERAL);
    }

    function testRevertIfTransferFromFails() public {
        // Arrange: The user has tokens but does NOT approve the engine to spend them.
        vm.startPrank(USER);

        // Act & Assert: The ERC20 contract itself should revert the transaction due to insufficient allowance.
        // We expect a generic revert because the error originates from the WETH contract, not DSCEngine.
        vm.expectRevert();
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////
    // Multi-Collateral Test //
    ///////////////////////////

    function testCanDepositMultipleCollateralTypes() public {
        // Arrange
        uint256 wethToDeposit = 1 ether; // Worth $2,000
        uint256 wbtcToDeposit = 1 ether; // Worth $1,000

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), wethToDeposit);
        ERC20Mock(wbtc).approve(address(engine), wbtcToDeposit);

        // Act
        engine.depositCollateral(weth, wethToDeposit);
        engine.depositCollateral(wbtc, wbtcToDeposit);

        // Assert
        uint256 totalCollateralValue = engine.getAccountCollateralValue(USER);
        uint256 expectedTotalValue = engine.getUsdValue(weth, wethToDeposit) + engine.getUsdValue(wbtc, wbtcToDeposit);

        assertEq(totalCollateralValue, expectedTotalValue);
        vm.stopPrank();
    }

    ///////////////////////
    // mintDsc Tests //
    ///////////////////////
    function testRevertsIfMintAmountIsZero() public {
        // Arrange: User deposits collateral first.
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Act & Assert: Expect a revert if minting 0.
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testCanMintDsc() public {
        // Arrange
        uint256 amountToMint = 100 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Act
        engine.mintDsc(amountToMint);
        vm.stopPrank();

        // Assert
        uint256 userDscBalance = dsc.balanceOf(USER);
        assertEq(userDscBalance, amountToMint);

        uint256 dscMinted = engine.getDscMinted(USER);
        assertEq(dscMinted, amountToMint);
    }

    function testRevertsIfHealthFactorIsBroken() public {
        // Arrange
        uint256 collateralValueInUsd = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 maxDscToMint =
            (collateralValueInUsd * engine.getLiquidationThreshold()) / engine.getLiquidationPrecision();
        uint256 amountToMint = maxDscToMint + 1;

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // We calculate the expected health factor manually, mirroring the contract's logic *during* the transaction.
        uint256 expectedHealthFactor = (collateralValueInUsd * engine.getLiquidationThreshold() * 1e18)
            / (engine.getLiquidationPrecision() * amountToMint);

        // Act & Assert: Expect the transaction to revert with the precise health factor value.
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    ///////////////////
    // burnDsc Tests //
    ///////////////////
    function testRevertsIfBurnAmountIsZero() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100 ether);
        dsc.approve(address(engine), 100 ether);

        // Act & Assert
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDsc() public {
        // Arrange: Deposit collateral and mint DSC
        uint256 amountToMint = 100 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);

        // To burn, the user must approve the engine to take their DSC
        dsc.approve(address(engine), amountToMint);

        // Act: Burn half the DSC
        uint256 amountToBurn = amountToMint / 2;
        engine.burnDsc(amountToBurn);
        vm.stopPrank();

        // Assert
        uint256 dscMinted = engine.getDscMinted(USER);
        assertEq(dscMinted, amountToMint - amountToBurn);
    }

    function testRevertsIfBurningMoreThanMinted() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100 ether);
        dsc.approve(address(engine), 101 ether); // Approve more than we have

        // Act & Assert
        // The revert will come from the DecentralizedStableCoin (ERC20) contract
        vm.expectRevert();
        engine.burnDsc(101 ether);
        vm.stopPrank();
    }

    ///////////////////////////
    // redeemCollateral Tests //
    ////////////////////////////
    function testRevertsIfRedeemAmountIsZero() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Act & Assert
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public {
        // Arrange: User deposits collateral and has no debt
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // Act
        vm.startPrank(USER);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        // Assert
        uint256 collateralDeposited = engine.getCollateralDeposited(USER, weth);
        assertEq(collateralDeposited, 0);
    }

    function testRevertsIfHealthFactorIsBrokenOnRedeem() public {
        // Arrange: User deposits collateral and mints DSC
        uint256 amountToMint = 100 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);

        // Act & Assert: User tries to redeem all collateral while still having debt
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testRevertsIfRedeemingMoreCollateralThanDeposited() public {
        // Arrange
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        // Act & Assert: Expect a revert due to underflow
        vm.expectRevert();
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);
        vm.stopPrank();
    }

    //////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////
    function testCanRedeemCollateralForDsc() public {
        // Arrange: User deposits collateral and mints DSC
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, DSC_MINT_AMOUNT);
        dsc.approve(address(engine), DSC_MINT_AMOUNT); // Approve DSC burn

        // Act: User burns all DSC and redeems all collateral
        engine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, DSC_MINT_AMOUNT);
        vm.stopPrank();

        // Assert
        uint256 dscMinted = engine.getDscMinted(USER);
        console2.log("Minted DSC: ", dscMinted);
        uint256 collateralDeposited = engine.getCollateralDeposited(USER, weth);
        assertEq(dscMinted, 0);
        assertEq(collateralDeposited, 0);
    }

    /////////////////////
    // liquidate Tests //
    /////////////////////
    function testRevertsIfHealthFactorIsOk() public {
        // Arrange: A user with a healthy position
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100 ether);
        vm.stopPrank();

        // Act & Assert: Another user tries to liquidate them
        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, 10 ether);
        vm.stopPrank();
    }

    function testCanBeLiquidated() public {
        // Arrange
        address liquidatee = USER;
        address liquidator = makeAddr("liquidator");

        // Liquidator needs DSC to pay off debt.
        // We'll give them WETH and have them mint their own DSC.
        uint256 liquidatorWethAmount = 20000 ether;
        ERC20Mock(weth).mint(liquidator, liquidatorWethAmount);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(engine), liquidatorWethAmount);
        // Mint enough DSC to cover the future debt
        uint256 dscToMintForLiquidator = 10000 ether;
        engine.depositCollateralAndMintDsc(weth, liquidatorWethAmount, dscToMintForLiquidator);
        vm.stopPrank();

        // Liquidatee deposits collateral and mints the MAXIMUM possible DSC to be on the edge of liquidation
        vm.startPrank(liquidatee);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        uint256 collateralValueInUsd = engine.getUsdValue(weth, AMOUNT_COLLATERAL);
        uint256 maxDscToMint =
            (collateralValueInUsd * engine.getLiquidationThreshold()) / engine.getLiquidationPrecision();
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, maxDscToMint);
        vm.stopPrank();

        // Act
        // Make the liquidatee's position unhealthy by dropping the collateral price just a little bit
        int256 newPrice = 1999e8; // ETH price drops from $2000 to $1999
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(newPrice);

        // Now the health factor should be < 1
        uint256 debtToCover = 100 ether; // Liquidator will cover a portion of the debt

        uint256 startingLiquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);

        vm.startPrank(liquidator);
        // Liquidator must approve the engine to take their DSC for the burn
        dsc.approve(address(engine), debtToCover);
        engine.liquidate(weth, liquidatee, debtToCover);
        vm.stopPrank();

        // Assert
        uint256 endingLiquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 liquidateeDscMinted = engine.getDscMinted(liquidatee);

        // Check if the liquidatee's debt was reduced
        assertEq(liquidateeDscMinted, maxDscToMint - debtToCover);
        // Check if the liquidator received the collateral plus the bonus
        assertTrue(endingLiquidatorWethBalance > startingLiquidatorWethBalance);
    }
}
