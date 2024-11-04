import { expect } from "chai";
import { ethers } from "hardhat";
import { Contract, Signer } from "ethers";

describe("Masternode Test", function () {
  let xdcDiamond: Contract, getterFacet: Contract, masternodeFacet: Contract;
  let owner: Signer, user: Signer, otroUser: Signer, recipientFee: Signer;
  const _tokenMasternodeURI = "example.master.uri";
  let minXDCToCreate = ethers.utils.parseEther("1000");

  function getSelectors(contract: Contract) {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.reduce((acc: string[], val) => {
      acc.push(contract.interface.getSighash(val));
      return acc;
    }, []);
  }

  before(async function () {
    [owner, user, otroUser, recipientFee] = await ethers.getSigners();
    const XDCDiamond = await ethers.getContractFactory("XDCVaultMasternodeDiamond");
    xdcDiamond = await XDCDiamond.deploy();
    await xdcDiamond.deployed();
  });

  it("Should deploy masternode facet and add it to the diamond", async function () {
    const MasternodeFacet = await ethers.getContractFactory("MasternodeFacet");
    masternodeFacet = await MasternodeFacet.deploy();
    await masternodeFacet.deployed();

    const cut = [
      {
        target: masternodeFacet.address,
        action: 0,
        selectors: getSelectors(masternodeFacet),
      },
    ];

    const tx = await xdcDiamond.diamondCut(cut, ethers.constants.AddressZero, "0x");
    await tx.wait();

    masternodeFacet = await ethers.getContractAt("MasternodeFacet", xdcDiamond.address);
    const initTx = await masternodeFacet.initialize(
      minXDCToCreate, await recipientFee.getAddress(), _tokenMasternodeURI
    );
    await initTx.wait();
  });

  it("Should add getter functions to the diamond", async function () {
    const GetterFacet = await ethers.getContractFactory("VaultGetterFacet");
    getterFacet = await GetterFacet.deploy();
    await getterFacet.deployed();

    const cut = [
      {
        target: getterFacet.address,
        action: 0,
        selectors: getSelectors(getterFacet),
      },
    ];

    const tx = await xdcDiamond.diamondCut(cut, ethers.constants.AddressZero, "0x");
    await tx.wait();

    getterFacet = await ethers.getContractAt("VaultGetterFacet", xdcDiamond.address);
  });

  it("should allow authorized user to set minXDCToCreateMasternode", async function () {
    minXDCToCreate = ethers.utils.parseEther("1500");
    await masternodeFacet.connect(owner).setMinXDC(minXDCToCreate);
    const min = await getterFacet.getMinMasternode();
    expect(min).to.equal(minXDCToCreate);
  });

  it("should not allow unauthorized users to set minXDCToCreateMasternode", async function () {
    const newMinXDC = ethers.utils.parseEther("2000");
    await expect(masternodeFacet.connect(user).setMinXDC(newMinXDC)).to.be.revertedWith("Unauthorized()");
  });

  it("should mint a masternode NFT", async function () {
    await masternodeFacet.connect(user).safeMintMaster({ value: minXDCToCreate });
    const balance = await masternodeFacet.balanceOf(await user.getAddress());
    expect(await masternodeFacet.ownerOf(1)).to.equal(await user.getAddress());
    expect(balance).to.equal(1);
  });

  it("should not mint masternode NFT with insufficient funds", async function () {
    const insufficientXDC = ethers.utils.parseEther("500");
    await expect(masternodeFacet.connect(user).safeMintMaster({ value: insufficientXDC }))
      .to.be.revertedWith('InsufficientXDC()');
  });

  it("should distribute rewards to all masternode holders", async function () {
    await ethers.provider.send("evm_increaseTime", [10 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);
    
    await masternodeFacet.connect(user).safeMintMaster({ value: minXDCToCreate });

    await ethers.provider.send("evm_increaseTime", [22 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    const rewardAmount = ethers.utils.parseEther("50");
    const rewardFakeAmount = ethers.utils.parseEther("10");

    await expect(masternodeFacet.connect(owner).setMasternodeRewards({ value: rewardFakeAmount })).to.be.revertedWith('InsufficientXDC()');

    await masternodeFacet.connect(owner).setMasternodeRewards({ value: rewardAmount });
    const totalAmountOfRewardsPaidToMasternode = await getterFacet.getTotalAmountOfRewardsPaid();

    let rewardPaidToANFT1 = (await getterFacet.getNFTData(1)).rewardData.rewardsAmount;
    const rewardPaidToANFT2 = (await getterFacet.getNFTData(2)).rewardData.rewardsAmount;

    expect(totalAmountOfRewardsPaidToMasternode).to.equal(rewardAmount);
  });

  it("should request withdrawal of XDC from masternode", async function () {
    const tokenId = 1;
    await masternodeFacet.connect(user).requestWithdrawXDCFromMasternode(tokenId);
    const nftData = await getterFacet.getNFTData(tokenId);
    expect(nftData.lockedData.unlockTimestamp).to.be.gt(0);
  });

  it("should revert if non-owner tries to withdraw XDC", async function () {
    const tokenId = 1;
    await expect(masternodeFacet.connect(owner).requestWithdrawXDCFromMasternode(tokenId))
      .to.be.revertedWith('NotOwner()');
  });

  it("should burn and redeem masternode NFT", async function () {
    const tokenId = 1;
    await ethers.provider.send("evm_increaseTime", [32 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    expect(await masternodeFacet.ownerOf(1)).to.equal(await user.getAddress());
    await masternodeFacet.connect(user).burnAndRedeemMasternode(tokenId);
    const balance = await masternodeFacet.balanceOf(await user.getAddress());
    expect(balance).to.equal(1);
  });

  it("should revert if trying to burn locked masternode", async function () {
    const tokenId = 2;
    await masternodeFacet.connect(user).safeMintMaster({ value: minXDCToCreate });
    await expect(masternodeFacet.connect(user).burnAndRedeemMasternode(tokenId)).to.be.revertedWith('TokenLocked()');
  });

  it("Should revert if the sender is not the token owner", async function () {
    const tokenId = 3;
    await masternodeFacet.connect(user).safeMintMaster({ value: minXDCToCreate });
    await expect(masternodeFacet.connect(otroUser).InstantWithdrawXDC(tokenId)).to.be.revertedWith('NotOwner()');
  });

  it("Should cap the fee when days exceed 32", async function () {
    await masternodeFacet.connect(otroUser).safeMintMaster({ value: minXDCToCreate });

    const expectedFee = minXDCToCreate;
    await masternodeFacet.connect(otroUser).InstantWithdrawXDC(5);

    const recipientBalance = await ethers.provider.getBalance(await recipientFee.getAddress());
    expect(recipientBalance).to.equal(expectedFee.add(ethers.utils.parseEther("10000")));
  });

  it("Should calculate the fee correctly when days are under 32", async function () {
    const recipientBalanceBefore = await ethers.provider.getBalance(await recipientFee.getAddress());
    await ethers.provider.send("evm_increaseTime", [355 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    await masternodeFacet.connect(user).InstantWithdrawXDC(3);
    const recipientBalanceAfter = await ethers.provider.getBalance(await recipientFee.getAddress());
    expect(recipientBalanceAfter).to.equal(recipientBalanceBefore.add("421875000000000000000"));
  });

  it("Should send the remaining amount to the token owner after fee", async function () {
    await masternodeFacet.connect(owner).safeMintMaster({ value: minXDCToCreate });
    const initialOwnerBalance = ethers.utils.formatEther(await ethers.provider.getBalance(await owner.getAddress()));
    await ethers.provider.send("evm_increaseTime", [355 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);

    await masternodeFacet.connect(owner).InstantWithdrawXDC(6);
    const finalOwnerBalance =ethers.utils.formatEther( await ethers.provider.getBalance(await owner.getAddress()));

    const difference = Number(finalOwnerBalance)-Number(initialOwnerBalance);
    const expectedDifference = 1078.025
    const tolerance = 1;
    
    expect(difference).to.be.closeTo(expectedDifference, 1);
      });

  it("Should burn the token after successful withdrawal", async function () {
    await masternodeFacet.connect(owner).safeMintMaster({ value: minXDCToCreate });
    await masternodeFacet.connect(owner).InstantWithdrawXDC(7);
    await expect(masternodeFacet.ownerOf(6)).to.be.revertedWith('InvalidTokenId()');
  });
});
