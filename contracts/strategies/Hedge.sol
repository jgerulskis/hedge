// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IHedge } from "../interfaces/IHedge.sol";
import { LyraWrapper } from "../wrappers/LyraWrapper.sol";
import { DecimalMath } from "../libraries/DecimalMath.sol";
import { SynthetixWrapper } from "../wrappers/SynthetixWrapper.sol";


/// @title A strategy that buys a long call and shorts delta equivalent amount of the call
/// @notice This strategy is used to demonstrate a hedged call, but is not recommended for production
/// This contract only is executable by an owner so that margin isn't mixed between users.
/// Additional mappings in the SynthetixWrapper contract would be needed to support multiple users.
contract Hedge is IHedge, LyraWrapper, SynthetixWrapper, Ownable {
    using DecimalMath for uint;

    Position private _currentPosition;

    constructor(
        address lyraRegistry,
        address optionMarket,
        address snxPerpsProxy,
        address snxQuoteAsset
    ) LyraWrapper(lyraRegistry, optionMarket) SynthetixWrapper(snxPerpsProxy, snxQuoteAsset) Ownable() {}

    /// @notice Buys a straddle by buying equivalent amount of call and put options
    /// @param _strikeId The strike id
    /// @param _amount of contracts to buy for call and put
    function buyHedgedCall(
        uint256 _strikeId,
        uint256 _amount
    ) external onlyOwner() {
        if (_currentPosition.owner != address(0)) {
            revert PositionAlreadyOpen();
        }
        
        Result memory result = _openLongCall(_strikeId, _amount);
        uint256 callDelta = uint256(_getCallDelta(_strikeId));
        uint256 amountToShort = _amount.multiplyDecimal(callDelta);
        _openShort(2000 ether, amountToShort); // TODO: don't hardcode margin, add a reasonable buffer to add to short if needed

        _currentPosition = Position({
            owner: msg.sender,
            strikeId: _strikeId,
            positionId: result.positionId,
            callAmount: _amount,
            shortAmount: amountToShort,
            lastHedge: block.timestamp
        });

        emit PositionOpened(_currentPosition);
    }

    function rehedge() external onlyOwner() {
        if (_currentPosition.owner == address(0)) {
            revert NoPositionOpen();
        }

        uint256 newCallDelta = uint256(_getCallDelta(_currentPosition.strikeId));
        uint256 newShortPosition = _currentPosition.callAmount.multiplyDecimal(newCallDelta);
        int256 deltaToHedge = int256(_currentPosition.shortAmount) - int256(newShortPosition);

        _rehedge(deltaToHedge);

        _currentPosition = Position({
            owner: _currentPosition.owner,
            strikeId: _currentPosition.strikeId,
            positionId: _currentPosition.positionId,
            callAmount: _currentPosition.callAmount,
            shortAmount: newShortPosition,
            lastHedge: block.timestamp
        });

        emit PositionRehedged(_currentPosition);
    }

    // TODO: add more functionality to have the owner manage their Short position
}