// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {LibString} from "../libraries/LibString.sol";
import {ERC721Facet} from "./ERC721Facet.sol";
import {ABDKMathQuad} from "../libraries/ABDKMathQuad.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import '../interfaces/IFeeds.sol';
import "../shared/Structs.sol";

contract XDCVault is ERC721Facet {
    
    /// @notice Event emitted when NFTs are minted.
    event NFTsMinted(address owner, uint256 stokenId);

    /// @notice Event emitted when staking in an NFT occurs.
    event StakeInNFT(address staker, uint256 tokenId, uint256 stakeAmount);

    /// @notice Event emitted when a reward is added.
    event RewardAdded(uint256 reward, uint256 periodFinish);

    /// @notice Event emitted when a reward is paid out.
    event RewardPaid(uint256 tokenId, uint256 reward);

    /// @notice Event emitted when a token is burned and redeemed.
    event BurnAndRedeem(uint256 tokenID, uint256 amount);

    /// @notice Event emitted when an NFT is locked.
    event NFTLocked(address staker, uint256 tokenId, uint256 lockTimestamp);

    /// @notice Event emitted when an NFT is unlocked.
    event NFTunlocked(address staker, uint256 tokendId);

    IFeeds public priceOracle;

    /// @notice Initializes the contract with necessary parameters.
    /// @param _priceOracleAddress The address of the price oracle.
    /// @param _prntAddress The address of the PRNT token.
    /// @param _rewardsDistribution Address responsible for distributing rewards.
    /// @param _minPRNT Minimum PRNT tokens required to mint.
    /// @param _periodFinish Period end for rewards.
    /// @param _rewardRate Reward rate.
    /// @param _tokenVaultURI URI for token vault metadata.
    /// @param _name Name of the token.
    /// @param _symbol Symbol of the token.
    function initialize(
        address _priceOracleAddress,
        address _prntAddress,
        address _rewardsDistribution,
        uint256 _minPRNT,
        uint256 _periodFinish,
        uint256 _rewardRate,
        string memory _tokenVaultURI,
        string memory _name,
        string memory _symbol
    ) external initializer {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.tokenVaultURI = _tokenVaultURI;
        appStorage.name_ = _name;
        appStorage.symbol_ = _symbol;
        priceOracle = IFeeds(_priceOracleAddress);
        appStorage.rewardRate = _rewardRate;
        appStorage.periodFinish = _periodFinish;
        appStorage.rewardDistribution = _rewardsDistribution;
        appStorage.prntAddress = _prntAddress;
        appStorage.minPRNT = _minPRNT;
    }

    /// @notice Fetches the latest price from the price oracle.
    /// @return Latest price from the oracle.
    function getLastRound() public view returns (uint256) {
        return priceOracle.latestAnswer();
    }

    /// @notice Provides the contract's metadata URI.
    /// @return Metadata URI.
    function contractURI() public pure returns (string memory) {
        return "https://ejemplo.com/contract.json";
    }

    /// @notice Sets the token metadata URI.
    /// @param _tokenVaultURI The new metadata URI.
    function setTokenMetaDataURI(string memory _tokenVaultURI) public onlyAuthorized {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.tokenVaultURI = _tokenVaultURI;
    }

    /// @notice Sets the minimum PRNT tokens required to mint.
    /// @param _minPRNT The minimum PRNT token amount.
    function setMinPRNT(uint _minPRNT) public onlyAuthorized {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        appStorage.minPRNT = _minPRNT;
    }

    /// @notice Safely mints a new NFT after checking PRNT token balance.
    function safeMint() external nonReentrant {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        uint256 currentPrice = getLastRound();
        uint256 balance = IERC20(appStorage.prntAddress).balanceOf(msg.sender);
        
        require(((currentPrice * 10**2) * balance) / (10**18) >= appStorage.minPRNT, "NotEnoughPRNT");

        appStorage.currentTokenId++;
        uint256 tokenId = appStorage.currentTokenId;
        appStorage.nftData[tokenId].typeOfNft = typeOfNFT.XDCVAULT;
        appStorage.myTokens[msg.sender].push(tokenId);
        mint(msg.sender, tokenId, appStorage.tokenVaultURI);
        _setTokenURI(tokenId, appStorage.tokenVaultURI);

        emit NFTsMinted(msg.sender, tokenId);
    }

    /// @notice Stakes an amount into an NFT, locking it for rewards.
    /// @param _tokenId The token ID to stake into.
    /// @param _amount The amount to stake.
    function stake(
        uint256 _tokenId,
        uint256 _amount
    ) public payable notPaused nonReentrant {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();

        require(_amount > 0, "InvalidStakeAmount");
        require(ownerOf(_tokenId) == msg.sender, "NotOwner");
        require(ownerOf(_tokenId) != address(0), "InvalidTokenId");
        require(msg.value == _amount, "InvalidStakeAmount");

        appStorage.totalSupply += _amount;
        appStorage.balanceByNFT[_tokenId] += _amount;
        appStorage.nftData[_tokenId].staked = appStorage.balanceByNFT[_tokenId];
        appStorage.nftData[_tokenId].lastTimeStaked = block.timestamp;

        emit StakeInNFT(msg.sender, _tokenId, _amount);
    }

    /// @notice Burns and redeems the NFT, transferring the staked balance to the owner.
    /// @param _tokenId The ID of the NFT to burn and redeem.
    function burnAndRedeem(uint _tokenId) public {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        require(ownerOf(_tokenId) == msg.sender, "NotOwner");
        require(!appStorage.tokenLocked[_tokenId], "TokenLocked");
        require(appStorage.balanceByNFT[_tokenId] > 0, "CannotWithdrawZero");

        getReward(_tokenId);
        uint amount = appStorage.balanceByNFT[_tokenId];
        removeKey(appStorage.myTokens[msg.sender], _tokenId);
        burn(_tokenId);
        appStorage.totalSupply -= amount;
        appStorage.balanceByNFT[_tokenId] = 0;
        delete appStorage.nftData[_tokenId];

        payable(msg.sender).transfer(amount);

        emit BurnAndRedeem(_tokenId, amount);
    }

    /// @notice Claims the reward for a specified NFT.
    /// @param _tokenId The ID of the NFT to claim rewards for.
    function getReward(uint _tokenId) public nonReentrant updateReward(_tokenId) {
        AppStorage storage appStorage = LibAppStorage.diamondStorage();
        require(ownerOf(_tokenId) == msg.sender, "NotOwner");
        require(appStorage.balanceByNFT[_tokenId] > 0, "NotNFTBalance");

        uint256 reward = appStorage.rewards[_tokenId];
        uint contractBalance = address(this).balance;
        
        if (reward > (contractBalance - appStorage.totalSupply - appStorage.totalMasternodeAmount)) {
            reward = contractBalance - appStorage.totalSupply - appStorage.totalMasternodeAmount;
        }

        if (reward > 0) {
            appStorage.nftData[_tokenId].rewardData.rewardsAmount += reward;
            appStorage.nftData[_tokenId].rewardData.lastTimeClaimed = block.timestamp;
            appStorage.nftData[_tokenId].rewardData.lastClaimedAmount = reward;
            appStorage.rewards[_tokenId] = 0;
            appStorage.totalSupply += reward;
            appStorage.balanceByNFT[_tokenId] += reward;
            appStorage.nftData[_tokenId].staked = appStorage.balanceByNFT[_tokenId];

            emit RewardPaid(_tokenId, reward);
        }
    }

    /// @notice Notifies the contract of a new reward amount and its duration.
    /// @param reward The amount of reward to add.
    /// @param rewardsDuration Duration for which the reward is active.
    function notifyRewardAmount(uint256 reward, uint256 rewardsDuration)
		external
		onlyRewardsDistribution
		updateReward(0)
		payable
	{
		AppStorage storage appStorage = LibAppStorage.diamondStorage();
		require(
			block.timestamp+rewardsDuration >= appStorage.periodFinish,
			CannotReducePeriod()
		);
		require(reward==msg.value,ValueDiffToReward());

		if (block.timestamp >= appStorage.periodFinish) {
			appStorage.rewardRate = reward/rewardsDuration;
		} else {
			uint256 remaining = appStorage.periodFinish - block.timestamp;
			uint256 leftover = remaining * appStorage.rewardRate;
			appStorage.rewardRate = (reward + leftover) / rewardsDuration;
		}

		uint256 balance = address(this).balance;
		require(
			appStorage.rewardRate <= balance/(rewardsDuration),
			RewardToohigh()
		);

		appStorage.lastUpdateTime = block.timestamp;
		appStorage.periodFinish = block.timestamp+(rewardsDuration);
		emit RewardAdded(reward, appStorage.periodFinish);
	}

	/**
 * @notice Locks the specified NFT for a minimum period of time if the stake amount meets the minimum lock requirement.
 * @dev This function sets the NFT's locked status and calculates the unlock timestamp based on `minLockedTime`.
 * @param _tokenId The ID of the NFT to be locked.
 * Requirements:
 * - Caller must own the NFT.
 * - NFT must not already be locked.
 * - NFT's staked amount must be at least `minLockedAmount`.
 * Emits a `NFTLocked` event on successful locking.
 */
function lockNFT(uint _tokenId) public {
    AppStorage storage s = LibAppStorage.diamondStorage();
    require(ownerOf(_tokenId) == msg.sender, NotOwner());
    require(!s.tokenLocked[_tokenId], TokenLocked());
    require(s.nftData[_tokenId].staked >= s.minLockedAmount, NotEnoughStaked());
    
    s.nftData[_tokenId].lockedData.unlockTimestamp = block.timestamp + s.minLockedTime;
    s.nftData[_tokenId].lockedData.lockedAmount = s.nftData[_tokenId].staked;
    s.tokenLocked[_tokenId] = true;

    emit NFTLocked(msg.sender, _tokenId, s.nftData[_tokenId].lockedData.unlockTimestamp);
}

/**
 * @notice Unlocks the specified NFT if it is currently locked.
 * @dev This function resets the NFT's locked status and clears its locked data.
 * @param _tokenId The ID of the NFT to be unlocked.
 * Requirements:
 * - Caller must own the NFT.
 * - NFT must currently be locked.
 * Emits a `NFTunlocked` event on successful unlocking.
 */
function unLockNFT(uint _tokenId) public {
    AppStorage storage s = LibAppStorage.diamondStorage();
    require(ownerOf(_tokenId) == msg.sender, NotOwner());
    require(s.tokenLocked[_tokenId], TokenNotLocked());

    s.nftData[_tokenId].lockedData.unlockTimestamp = 0;
    s.nftData[_tokenId].lockedData.lockedAmount = 0;
    s.tokenLocked[_tokenId] = false;

    emit NFTunlocked(msg.sender, _tokenId);
}


}