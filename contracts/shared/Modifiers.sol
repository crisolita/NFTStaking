// SPDX-License-Identifier: MIT

pragma solidity >=0.8.27;

import "../libraries/LibAppStorage.sol";
import "../facets/RewardFacet.sol";
import {Errors} from "../shared/Errors.sol";

/**
 * @notice Modifiers for controlling function access and updating reward states within the contract.
 */
abstract contract Modifiers is RewardFacet {
   
    /**
     * @notice Ensures that the contract is not paused before proceeding.
     * @dev Reverts with `StakerIsPaused` error if the contract is paused.
     */
    modifier notPaused() {
        if (LibAppStorage.diamondStorage().isPaused) revert Errors.StakerIsPaused();
        _;
    }

    /**
     * @notice Allows initialization to be executed only once.
     * @dev Reverts with `AlreadyInitialized` error if the contract has already been initialized.
     * Sets the `initialized` state variable to true upon execution.
     */
    modifier initializer() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.initialized) revert Errors.AlreadyInitialized();
        s.initialized = true;
        _;
    }

    /**
     * @notice Updates reward-related state variables before executing the modified function.
     * @dev Updates `rewardPerTokenStored` and `lastUpdateTime`. If `_tokenId` is valid, 
     * calculates and updates `rewards[_tokenId]` and `userRewardPerTokenPaid[_tokenId]`.
     * @param _tokenId The ID of the token for which rewards are being updated.
     */
    modifier updateReward(uint256 _tokenId) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.rewardPerTokenStored = rewardPerToken();
        s.lastUpdateTime = lastTimeRewardApplicable();

        if (_tokenId <= s.currentTokenId && _tokenId > 0) {
            s.rewards[_tokenId] = earned(_tokenId);
            s.userRewardPerTokenPaid[_tokenId] = s.rewardPerTokenStored;
        }
        _;
    }

    /**
     * @notice Restricts access to only the rewards distribution address.
     * @dev Reverts with `NotRewardDistribution` error if `msg.sender` is not the rewards distributor.
     */
    modifier onlyRewardsDistribution() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(
            msg.sender == s.rewardDistribution,
            Errors.NotRewardDistribution()
        );
        _;
    }

    /**
     * @notice Ensures that only authorized addresses can call the modified function.
     * @dev Reverts with `Unauthorized` error if `msg.sender` is not authorized.
     */
    modifier onlyAuthorized() {
        if (!LibAppStorage.diamondStorage().authorized[msg.sender]) revert Errors.Unauthorized();
        _;
    }
}
