  // SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract RewardFacet  {

     /**
     * @notice Returns the last time rewards are applicable within the current reward period.
     * @return The minimum value between the current block timestamp and the reward period finish timestamp.
     */
   function lastTimeRewardApplicable() public view  returns (uint256) {
      AppStorage storage s = LibAppStorage.diamondStorage();
		return Math.min(block.timestamp, s.periodFinish);
	}

/**
     * @notice Calculates the current reward per token.
     * @dev This function calculates the reward per token based on the time elapsed, the rate of rewards,
     *      and the total supply of staked tokens. If there is no staked supply, it simply returns the
     *      stored reward per token.
     * @return The cumulative reward per token.
     */
function rewardPerToken() public view returns (uint256) {
    AppStorage storage s = LibAppStorage.diamondStorage();
    if (s.totalSupply == 0) {
        return s.rewardPerTokenStored;
    }
    return
        s.rewardPerTokenStored +
        ((lastTimeRewardApplicable() - s.lastUpdateTime) * s.rewardRate * 1e18) / s.totalSupply;
}

 /**
     * @notice Calculates the rewards earned by a specific NFT.
     * @param _tokenId The ID of the NFT for which the rewards are being calculated.
     * @return The total rewards earned by the NFT.
     * @dev This function calculates earned rewards by taking the NFT's balance, multiplying it by
     *      the difference in reward per token since the last update for this NFT, and then adding
     *      any previously stored rewards.
     */
 function earned(uint256 _tokenId) public view returns (uint256) {
    AppStorage storage s = LibAppStorage.diamondStorage();
    uint256 balance = s.balanceByNFT[_tokenId];
  
    return 
        ((balance * (rewardPerToken() - s.userRewardPerTokenPaid[_tokenId])) / 1e18 
        + s.rewards[_tokenId]) ;
}

  

}

