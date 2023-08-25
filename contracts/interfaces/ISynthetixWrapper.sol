// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/// Interface for SynthetixWrapper
interface ISynthetixWrapper {  
    error InsufficientMargin(uint256 margin, uint256 shortAmount);
}