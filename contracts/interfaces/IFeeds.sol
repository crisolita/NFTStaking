// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;

interface IFeeds {
	function latestAnswer() external view returns (uint256);
	function latestRoundData() external view returns (uint80,uint256,uint256,uint256,uint80);
	function decimals() external view returns (uint8);
	function latestRound() external view returns (uint256);
	function owner() external view returns (address);
	function description() external view returns (string memory);
}
