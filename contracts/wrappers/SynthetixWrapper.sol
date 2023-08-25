// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { DecimalMath } from "../libraries/DecimalMath.sol";
import { ISynthetixWrapper } from "../interfaces/ISynthetixWrapper.sol";


/// @title A wrapper for Synthetix's perpetuals proxy
/// @notice Minimal viable implementation of a wrapper to interact with some core Synthetix functionality
contract SynthetixWrapper is ISynthetixWrapper {
    using DecimalMath for uint;

    address immutable internal _snxPerpsProxy;
    ERC20 immutable internal _snxQuoteAsset;

    constructor(address snxPerpsProxy, address quoteAddress) {
        _snxPerpsProxy = snxPerpsProxy;
        _snxQuoteAsset = ERC20(quoteAddress);

        _snxQuoteAsset.approve(address(_snxPerpsProxy), type(uint256).max);
    }

    /// @notice opens a short
    /// @param _margin The amount of margin to transfer
    /// @param _amountToShort The amount to short
    function _openShort(uint256 _margin, uint256 _amountToShort) internal {
        if (_margin < _amountToShort) {
            revert InsufficientMargin(_margin, _amountToShort);
        }

        _collectAssetsForPosition(_margin);
        _transferMargin(int256(_margin));
        _submitAtomicOrder(-int256(_amountToShort));
    }

    function _rehedge(int256 _amountToRehedge) internal {
        _submitAtomicOrder(_amountToRehedge);
    }

    function _getAssetPrice() internal view returns (uint256) {
        bytes memory payload = abi.encodeWithSignature("assetPrice()");
        (bool success, bytes memory data) = _snxPerpsProxy.staticcall(payload);

        if (!success) {
            revert(string(data));
        }

        (uint price) = abi.decode(data, (uint));
        return price;
    }

    /// @notice collect assets needed for position
    /// @param _amount The amount of contracts to buy
    function _collectAssetsForPosition(uint256 _amount) private {
        bool transferSuccess = _snxQuoteAsset.transferFrom(msg.sender, address(this), _amount);
        
        if (!transferSuccess) {
            revert("Transfer failed");  
        }
    }

    /// @notice transfer margin for orders
    /// @param _amount The amount of margin to transfer
    function _transferMargin(int256 _amount) internal {
        bytes memory payload = abi.encodeWithSignature("transferMargin(int256)", _amount);
        (bool success, bytes memory data) = _snxPerpsProxy.call(payload);

        if (!success) {
            revert(string(data));
        }
    }

    /// @notice submits an atomic order
    /// An atomic order is used to demostrate a hedged short but is not recommended for production
    /// Delayed orders are next best and have a much cheaper transaction cost
    /// Delayed off chain orders are the best option for production, but require keepers which makes testing difficult
    /// @param _sizeDelta The size of the order
    /// @dev see: https://docs.synthetix.io/integrations/perps-integration-guide/technical-integration#atomic-orders-do-not-use-this-trading-method
    function _submitAtomicOrder(int256 _sizeDelta) private {       
        bytes memory payload = abi.encodeWithSignature(
            "modifyPosition(int256,uint256)",
            _sizeDelta,
            0
        );
        (bool success, bytes memory data) = _snxPerpsProxy.call(payload);
        
        if (!success) {
            revert(string(data));
        }
    }
}