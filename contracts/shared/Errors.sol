// SPDX-License-Identifier: MIT

pragma solidity>= 0.8.23;

abstract contract Errors {
    error AddressZero();
    error Unauthorized();
    error InvalidTokenId();
    error InvalidTokenOwner();
    error InvalidStakeAmount();
    error TokenLocked();
    error NotEnoughStaked();
    error AlreadyInitialized();
    error TokenNotLocked();
    error NonERC721Receiver();
    error ERC721InvalidInput();
    error ERC721OutOfBoundsIndex(address, uint256);
    error InvalidLockConfig();
    error StakerIsPaused();
    error InsufficientBalance();
    error ERC721NonexistentToken();
    error InvalidTo();
    error InvalidFrom();
    error NotApproved();
    error AlreadyMinted();
    error NotOwner();
    error NotEnoughPRNT();
    error CannotWithdrawZero();
    error NotNFTBalance();
    error ValueDiffToReward();
    error CannotReducePeriod();
    error RewardToohigh();
    error InsufficientXDC();
    error NotMasternode();
    error TransferFailed();
    error ZeroMasternodes();
    error NotRewardDistribution();

}