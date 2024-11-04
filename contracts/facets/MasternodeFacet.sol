// SPDX-License-Identifier: MIT

pragma solidity >=0.8.23;
import {ERC721Facet} from "./ERC721Facet.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import "../libraries/ApyCalculation.sol";
import "../shared/Structs.sol";
// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MasternodeFacet is ERC721Facet  {
    event MasternodeRewadDelivered(uint256 amount,uint256[] ids,uint256 time);
    event RequestedWithdraw(uint256 _tokenId,uint256 time);
    event BurnAndRedeem(uint256 tokenID,uint256 amount);
    event NFTsMinted(address owner,uint256 stokenId);


 /**
     * @notice Initializes the masternode settings
     * @param _minXDCToCreate Minimum XDC required to create a masternode
     * @param _recipientFeeAddress Address where fees will be sent
     * @param _tokenMasternodeURI URI for the metadata of the masternode NFT
     */
    function initialize(
      uint256 _minXDCToCreate,
      address _recipientFeeAddress,
      string memory _tokenMasternodeURI
    ) external initializer {
     AppStorage storage appStorage = LibAppStorage.diamondStorage();
     appStorage.minXDCToCreateMasternode=_minXDCToCreate;
    appStorage.recipientFeeAddress=_recipientFeeAddress;
    	appStorage.tokenMasternodeURI=_tokenMasternodeURI;
     appStorage.authorized[msg.sender]=true;
    }

      /**
     * @notice Returns the contract metadata URI
     * @return A string representing the contract's metadata URI
     */
    function contractURI() public pure returns (string memory) {
        return "https://ejemplo.com/contract.json";
}

/**
     * @notice Sets the URI for the masternode token metadata
     * @param _tokenMasternodeURI New URI to set for masternode tokens
     */
function setTokenMetaDataURI(string memory _tokenMasternodeURI) public onlyAuthorized() {
	AppStorage storage appStorage = LibAppStorage.diamondStorage();

    appStorage.tokenMasternodeURI=_tokenMasternodeURI;
}
/**
     * @notice Updates the address where transaction fees are sent
     * @param _recipientFeeAddress New address to set as fee recipient
     */
function setFeeAddress(address _recipientFeeAddress) public onlyAuthorized() {
     AppStorage storage appStorage = LibAppStorage.diamondStorage();
     appStorage.recipientFeeAddress=_recipientFeeAddress;

}

 /**
     * @notice Sets the minimum XDC required to create a masternode
     * @param _minXDCToCreate New minimum XDC amount
     */
function setMinXDC(uint _minXDCToCreate) public onlyAuthorized() {
     AppStorage storage appStorage = LibAppStorage.diamondStorage();
     appStorage.minXDCToCreateMasternode=_minXDCToCreate;

}

  /**
     * @notice Mints a new masternode NFT by locking XDC in the contract
     */
 function safeMintMaster(
    ) external payable nonReentrant {
         AppStorage storage appStorage = LibAppStorage.diamondStorage();
    require(msg.value >= appStorage.minXDCToCreateMasternode, InsufficientXDC());
			appStorage.currentTokenId++;
            uint tokenId=appStorage.currentTokenId;
			appStorage.nftData[tokenId].typeOfNft=typeOfNFT.MASTERNODEXDC;
            appStorage.nftData[tokenId].lockedData.lockedAmount=appStorage.minXDCToCreateMasternode;
            appStorage.nftData[tokenId].lockedData.unlockTimestamp=block.timestamp+  365 days;
            appStorage.masterIds.push(tokenId);
            appStorage.totalMasternodeAmount=appStorage.totalMasternodeAmount+appStorage.minXDCToCreateMasternode;
            appStorage.nftData[tokenId].rewardData.lastTimeClaimed=block.timestamp;
            mint(msg.sender,tokenId,appStorage.tokenMasternodeURI);
            _setTokenURI(tokenId, appStorage.tokenMasternodeURI);
            appStorage.myTokens[msg.sender].push(tokenId);
        emit NFTsMinted( msg.sender,tokenId);
    }

/**
     * @notice Calculates and distributes rewards for all masternode holders
     */
function setMasternodeRewards() public payable {
     AppStorage storage appStorage = LibAppStorage.diamondStorage();
     require(appStorage.masterIds.length>0,ZeroMasternodes());
    uint totalAmountToPay;
    for (uint i=0;i<appStorage.masterIds.length;i++) {
        uint id=appStorage.masterIds[i];
        if(appStorage.nftData[id].typeOfNft==typeOfNFT.MASTERNODEXDC) {
        uint amountOfXDC=appStorage.nftData[id].lockedData.lockedAmount;
        uint amountToPay=ApyCalculation.calculatePartialReward(appStorage.nftData[id].rewardData.lastTimeClaimed,775,amountOfXDC);
            totalAmountToPay+=amountToPay;
            (bool success, ) = payable(ownerOf(id)).call{value: amountToPay}("");
            require(success, TransferFailed());
            appStorage.nftData[id].rewardData.rewardsAmount=appStorage.nftData[id].rewardData.rewardsAmount+amountToPay;
            appStorage.nftData[id].rewardData.lastTimeClaimed=block.timestamp;
            appStorage.nftData[id].rewardData.lastClaimedAmount=amountToPay;
        }
    }
     require(msg.value>=totalAmountToPay*appStorage.masterIds.length,InsufficientXDC());
    appStorage.totalAmountOfRewardsPaidToMasternode=msg.value;
    emit MasternodeRewadDelivered(msg.value,appStorage.masterIds,block.timestamp);
}

 /**
     * @notice Requests the withdrawal of locked XDC from a masternode, initiating a 32-day unlock period
     * @param _tokenId ID of the masternode NFT
     */
function requestWithdrawXDCFromMasternode(uint _tokenId) public  {
AppStorage storage appStorage = LibAppStorage.diamondStorage();
require(ownerOf(_tokenId)==msg.sender,NotOwner());
require(appStorage.nftData[_tokenId].typeOfNft==typeOfNFT.MASTERNODEXDC,NotMasternode());
appStorage.nftData[_tokenId].lockedData.unlockTimestamp=block.timestamp+32 days;
emit RequestedWithdraw(_tokenId,block.timestamp);
}

 /**
     * @notice Burns and redeems a masternode NFT, transferring locked XDC to the owner
     * @param _tokenId ID of the masternode NFT to burn
     */
function burnAndRedeemMasternode(uint256 _tokenId) public {
    	 AppStorage storage appStorage = LibAppStorage.diamondStorage();
         address owner=ownerOf(_tokenId);
		require(owner==msg.sender,NotOwner());
		require(block.timestamp>=appStorage.nftData[_tokenId].lockedData.unlockTimestamp,TokenLocked());
		 uint amount=appStorage.nftData[_tokenId].lockedData.lockedAmount;
		appStorage.myTokens[msg.sender]= removeKey(appStorage.myTokens[msg.sender],_tokenId);
        appStorage.masterIds=removeKey(appStorage.masterIds,_tokenId);
		burn(_tokenId);
		appStorage.totalMasternodeAmount = appStorage.totalMasternodeAmount-amount;
		delete appStorage.nftData[_tokenId];
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, TransferFailed());		
        emit BurnAndRedeem(_tokenId, amount);
}

 /**
     * @notice Instantly withdraws locked XDC from a masternode with a fee based on early withdrawal
     * @param _tokenId ID of the masternode NFT for instant withdrawal
     */
function InstantWithdrawXDC(uint256 _tokenId) public {
     AppStorage storage appStorage = LibAppStorage.diamondStorage();
         address owner=ownerOf(_tokenId);
		require(owner==msg.sender,NotOwner());
		 uint amount=appStorage.nftData[_tokenId].lockedData.lockedAmount;
         uint fee= ApyCalculation.getTheFee(appStorage.nftData[_tokenId].lockedData.unlockTimestamp, amount);
         if(fee>0) {
            amount=amount-fee;
             (bool successFee, ) = payable(appStorage.recipientFeeAddress).call{value: fee}("");
            require(successFee, TransferFailed());
         } 
		appStorage.myTokens[msg.sender]= removeKey(appStorage.myTokens[msg.sender],_tokenId);
        appStorage.masterIds=removeKey(appStorage.masterIds,_tokenId);
		burn(_tokenId);
		appStorage.totalMasternodeAmount = appStorage.totalMasternodeAmount-amount-fee;
		delete appStorage.nftData[_tokenId];
        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, TransferFailed());		
        emit BurnAndRedeem(_tokenId, amount);
}

    
}