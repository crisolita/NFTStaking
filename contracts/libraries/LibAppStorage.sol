// SPDX-License-Identifier: MIT

pragma solidity>= 0.8.23;

import "../shared/Structs.sol";

struct AppStorage {
 IERC20 prnt;
bool initialized;
bool isPaused;
uint256 reentrancyStatus;
uint256 currentTokenId;
uint256 totalSupply;
uint256 totalRewards;
uint256 rewardsDuration;
uint256 periodFinish;
uint256 rewardPerTokenStored;
uint256 rewardRate;
uint256 minLockedAmount;
uint256 minLockedTime;
uint256 lastUpdateTime;
uint256 totalMasternodeAmount;
uint256 totalAmountOfRewardsPaidToMasternode;
uint256 minXDCToCreateMasternode;
uint256 minPRNT;
uint256[] masterIds;
address prntAddress;
address recipientFeeAddress;
address rewardDistribution;
string tokenVaultURI;
string tokenMasternodeURI;
string name_;
string symbol_;
mapping (uint256 tokendId=>uint256 _balances) balanceByNFT;
mapping (uint256 tokenId=>uint256 _earned) earnedByNFT;
mapping(uint256 tokenId=>uint256 reward) rewards;
mapping(address user => bool accessGranted) authorized;
mapping(uint256 tokenId => bool) tokenLocked;
mapping (uint256 tokenId=>uint256 urptp) userRewardPerTokenPaid;
mapping(uint256 tokenId=>NftData) nftData;
mapping(address owner=>uint256[]tokenIds) myTokens;
}

library LibAppStorage {
    bytes32 internal constant DIAMOND_APP_STORAGE_POSITION =
        keccak256("primenumbers.contracts.storage.AppStorage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = DIAMOND_APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}