// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ILyraRegistry } from "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

import { ILyraWrapper } from "../interfaces/ILyraWrapper.sol";
import { DecimalMath } from "../libraries/DecimalMath.sol";


/// @title A wrapper for Lyra's registry, gwav, and option market
/// @notice Minimal viable implementation of a wrapper to interact with some core Lyra functionality
contract LyraWrapper is ILyraWrapper {
    using DecimalMath for uint;

    ILyraRegistry immutable internal _lyraRegistry;
    address immutable internal _optionMarket;
    address immutable internal _gwavOracle;
    ERC20 immutable internal _lyraQuoteAsset;
    IERC721Enumerable immutable internal _optionToken;

    constructor(address lyraRegistry, address optionMarket) {
        _lyraRegistry = ILyraRegistry(lyraRegistry);
        _optionMarket = optionMarket;
        ILyraRegistry.OptionMarketAddresses memory optionMarketAddresses = _lyraRegistry.getMarketAddresses(optionMarket);
        _gwavOracle = optionMarketAddresses.gwavOracle;
        _lyraQuoteAsset = ERC20(address(optionMarketAddresses.quoteAsset));
        _optionToken = IERC721Enumerable(optionMarketAddresses.optionToken);

        _lyraQuoteAsset.approve(address(_optionMarket), type(uint256).max);
    }

    /// @notice Gets the quote asset amount required to buy a straddle
    /// Parses the amount to be in the corect units for the quote asset
    /// @param _amount The amount of contracts to buy for call and put
    /// @param _strikeId The strike id
    /// @return The quote asset amount required to buy _amount of long call options
    function getQuoteAssetAmountFromOptionsAmount(
        uint256 _amount,
        uint256 _strikeId
    ) external view returns (uint256) {
        bytes memory payload = abi.encodeWithSignature("optionPriceGWAV(uint256,uint256)", _strikeId, 1);
        (bool success, bytes memory data) = _gwavOracle.staticcall(payload);
        if (!success) {
            revert(string(data));
        }

        (uint256 callPrice) = abi.decode(data, (uint256));
        uint256 adjustmentFactor = _lyraQuoteAsset.decimals() == 18 ? 1 : 10 ** (18 - _lyraQuoteAsset.decimals());
        uint256 callPriceAdjusted = callPrice / adjustmentFactor;
        uint256 totalAmount = _amount * callPriceAdjusted / 1 ether;

        /// @dev add 10% buffer for option fees
        return totalAmount.multiplyByPercentage(110);
    }

    /// @notice opens a long call
    /// @param _strikeId The strike id
    /// @param _amount The amount of contracts to buy
    /// @return result - The position id, total cost, and total fee
    function _openLongCall(uint256 _strikeId, uint256 _amount) internal returns (Result memory) {
        _collectAssetsForPosition(_strikeId, _amount);
        (Result memory result) = _executeTrade(_strikeId, _amount);
        _transferAllTokens(result.positionId);
        return result;
    }

    /// @notice collect assets needed for position based on strike and amount
    /// @param _strikeId The strike id
    /// @param _amount The amount of contracts to buy
    function _collectAssetsForPosition(uint256 _strikeId, uint256 _amount) private {
        uint256 quoteAssetToTransfer = this.getQuoteAssetAmountFromOptionsAmount(_amount, _strikeId);
        bool transferSuccess = _lyraQuoteAsset.transferFrom(msg.sender, address(this), quoteAssetToTransfer);
        
        if (!transferSuccess) {
            revert TransferFailed(msg.sender, address(this), quoteAssetToTransfer);    
        }
    }

    /// @notice executes a trade for a long call
    /// @param _strikeId The strike id
    /// @param _amount The amount of contracts to buy
    /// @return result - The position id, total cost, and total fee
    function _executeTrade(uint256 _strikeId, uint256 _amount) private returns (Result memory) {
        TradeInputParameters memory longCallTradeParams = _createTradeParams(_strikeId, _amount, OptionType(0));
        bytes memory payload = abi.encodeWithSignature(
            "openPosition((uint256,uint256,uint256,uint8,uint256,uint256,uint256,uint256,address))",
            longCallTradeParams
        );

        (bool success, bytes memory data) = _optionMarket.call(payload);
        if (!success) {
            revert(string(data));
        }

        return abi.decode(data, (Result));
    }

    /// @notice trasnfer excess quote asset and option token to the original sender
    /// @param _positionId The position id
    function _transferAllTokens(uint256 _positionId) private {
        _refundExcessQuoteAsset();
        _transferOptionToken(_positionId);
    }

    /// @notice create trade params for a long call or long put
    /// @param _strikeId The strike id
    /// @param _amount The amount of contracts to buy
    /// @param _optionType The option type
    /// @return TradeInputParameters to open a position with
    function _createTradeParams(
        uint256 _strikeId,
        uint256 _amount,
        OptionType _optionType
    ) private pure returns (TradeInputParameters memory) {
        return TradeInputParameters({
            strikeId: _strikeId,
            positionId: 0,
            iterations: 1,
            optionType: _optionType,
            amount: _amount,
            setCollateralTo: 0,
            minTotalCost: 0,
            maxTotalCost: type(uint256).max,
            referrer: address(0)
        });
    }

    /// @notice transfer the option token the original sender
    function _transferOptionToken(uint256 _positionId) private {
        _optionToken.transferFrom(address(this), msg.sender, _positionId);
    }

    /// @notice Refunds any excess quote asset
    function _refundExcessQuoteAsset() private {
        uint256 _balance = _lyraQuoteAsset.balanceOf(address(this));
        if (_balance > 0) {
            _lyraQuoteAsset.transfer(msg.sender, _balance);
        }
    }

    /// @notice Gets the delta of a call option
    /// @param _strikeId The strike id
    /// @return delta of the call option
    function _getCallDelta(uint256 _strikeId) internal view returns (int256) {
        bytes memory payload = abi.encodeWithSignature("deltaGWAV(uint256,uint256)", _strikeId, 1);
        (bool success, bytes memory data) = _gwavOracle.staticcall(payload);

        if (!success) {
            revert(string(data));
        }

        (int256 callDelta) = abi.decode(data, (int256));
        return callDelta;
    }
}