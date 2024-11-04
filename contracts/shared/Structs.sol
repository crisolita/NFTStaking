// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


struct NftData {
    uint256 staked;
    uint lastTimeStaked;
    LockedData lockedData;
    RewardsData rewardData;
    string tokenURI;
    typeOfNFT typeOfNft;
}

struct RewardsData {
    uint256 rewardsAmount;
    uint lastClaimedAmount;
    uint lastTimeClaimed;
}

struct LockedData {
    uint256 lockedAmount;
    uint256 unlockTimestamp;
}
enum typeOfNFT {
    MASTERNODEXDC,
    XDCVAULT
}

