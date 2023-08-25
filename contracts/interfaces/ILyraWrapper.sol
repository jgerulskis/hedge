// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/// @notice Interface for LyraWrapper
interface ILyraWrapper {   
    enum OptionType {
        LONG_CALL,
        LONG_PUT,
        SHORT_CALL_BASE,
        SHORT_CALL_QUOTE,
        SHORT_PUT_QUOTE
    }

    struct TradeInputParameters {
        uint strikeId;
        uint positionId;
        uint iterations;
        OptionType optionType;
        uint amount;
        uint setCollateralTo;
        uint minTotalCost;
        uint maxTotalCost;
        address referrer;
    }

    struct Result {
        uint positionId;
        uint totalCost;
        uint totalFee;
    }

    error TransferFailed(address from, address to, uint256 amount);

    function getQuoteAssetAmountFromOptionsAmount(uint256 _amount, uint256 _strikeId) external view returns (uint256);
}