// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

contract AggregatorV3Mock {

    uint8   public decimals;
    int256  public answer;
    uint256 public startedAt;
    uint256 public updatedAt;

    constructor(uint8 _decimals) {
        decimals  = _decimals;
    }

    function setDecimals(uint8 _decimals) external {
        decimals = _decimals;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function setRoundData(
        int256  _answer,
        uint256 _startedAt,
        uint256 _updatedAt
    ) external {
        answer    = _answer;
        startedAt = _startedAt;
        updatedAt = _updatedAt;
    }

    function latestRoundData() external view returns (
        uint80,
        int256,
        uint256,
        uint256,
        uint80
    ) {
        return (0, answer, startedAt, updatedAt, 0);
    }

}
