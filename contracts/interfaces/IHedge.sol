// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


/// @notice Interface for the Hedge contract
interface IHedge {
    struct Position {
        address owner;
        uint256 strikeId;
        uint256 positionId;
        uint256 callAmount;
        uint256 shortAmount;
        uint256 lastHedge;
    }

    error NoPositionOpen();
    error PositionAlreadyOpen();

    event PositionOpened(Position position);
    event PositionRehedged(Position position);
    
    function buyHedgedCall(uint256 _strikeId, uint256 _amount) external;
    function rehedge() external;
}