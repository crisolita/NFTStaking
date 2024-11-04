// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;

import {LibAppStorage, AppStorage, NftData} from "../libraries/LibAppStorage.sol";
import {Modifiers} from "../shared/Modifiers.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
 contract VaultGetterFacet  {
	/**
     * @notice Returns the total supply of tokens in the contract.
     * @return totalSupply The total token supply as an integer.
     */
    function totalSupply() external view  returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
		return s.totalSupply;
	}

	/**
     * @notice Returns the name of the vault.
     * @return name The vault's name as a string.
     */
	function getName() external view returns (string memory) {
		 AppStorage storage s = LibAppStorage.diamondStorage();
		return s.name_;
	}

	 /**
     * @notice Retrieves the current reward rate for the vault.
     * @return RewardRate The reward rate as an integer.
     */
	function getRewardRate() external view returns (uint) {
		 AppStorage storage s = LibAppStorage.diamondStorage();
		return s.rewardRate;
	}

	/**
     * @notice Returns the symbol representing the vault's token.
     * @return symbol The token symbol as a string.
     */
	function getSymbol() external view returns (string memory) {
		 AppStorage storage s = LibAppStorage.diamondStorage();
		return s.symbol_;
	}

	/**
     * @notice Gets the minimum amount of XDC required to create a masternode.
     * @return minXDCToCreateMasternode The minimum XDC requirement as an integer.
     */
	function getMinMasternode() external view returns (uint) {
	AppStorage storage s = LibAppStorage.diamondStorage();
	return s.minXDCToCreateMasternode;
	}
	
	 /**
     * @notice Retrieves the rewards already paid to a specific NFT.
     * @param _tokenId The ID of the NFT.
     * @return userRewardPerTokenPaid The reward amount paid to the NFT as an integer.
     */
	function rewardsByNFT(uint _tokenId) public view returns (uint) {
		AppStorage storage s = LibAppStorage.diamondStorage();

		return s.userRewardPerTokenPaid[_tokenId];
	}

	/**
     * @notice Returns the total amount of rewards paid to all masternodes.
     * @return totalAmountOfRewardsPaidToMasternode The total rewards paid as an integer.
     */
	function getTotalAmountOfRewardsPaid() public view returns (uint) {
		AppStorage storage s = LibAppStorage.diamondStorage();
		return s.totalAmountOfRewardsPaidToMasternode;
	}

	 /**
     * @notice Retrieves the complete data for a specific NFT.
     * @param _tokenId The ID of the NFT.
     * @return nftData An `NftData` struct containing the NFT's data.
     */
	function getNFTData(uint _tokenId) public view returns (NftData memory) {
		AppStorage storage s = LibAppStorage.diamondStorage();
		return s.nftData[_tokenId];
	}

	 /**
     * @notice Retrieves the total reward amount accumulated by a specific NFT.
     * @param _tokenId The ID of the NFT.
     * @return rewardsAmount The reward amount as an integer.
     */
	function getNFTRewardAmount(uint _tokenId) public view returns (uint) {
		AppStorage storage s = LibAppStorage.diamondStorage();
		return s.nftData[_tokenId].rewardData.rewardsAmount;
	}
	
	  /**
     * @notice Returns the staked balance associated with a specific NFT.
     * @param _tokenId The ID of the NFT.
     * @return balanceOfStake The staked balance as an integer.
     */
	function balanceOfStake(uint _tokenId)
		public
		view
		
		returns (uint256)
	{
        AppStorage storage s = LibAppStorage.diamondStorage();
		return s.balanceByNFT[_tokenId];
	}

}