import { ethers } from "hardhat";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, BigNumber } from "ethers";

describe("XDC vault Test", function () {
  let PRNTAddress: string;
  let pnrt: Contract;
  let xdcDiamond: Contract;
  let getterFacet: Contract;
  let vaultContract: Contract;
  let diamondAddress: string;
  const oracleAddress = "0x3Ea54753e3Eb29ce0013C2eb9F57c636037c4f8f";
  let owner: SignerWithAddress;
  let rewardsDistribution: SignerWithAddress;
  let user: SignerWithAddress;
  let otroUser: SignerWithAddress;

  function getSelectors(contract: Contract): string[] {
    const signatures = Object.keys(contract.interface.functions);
    return signatures.reduce((acc: string[], val: string) => {
      acc.push(contract.interface.getSighash(val));
      return acc;
    }, []);
  }

  before(async function () {
    [owner, rewardsDistribution, user, otroUser] = await ethers.getSigners();

    const PNRT = await ethers.getContractFactory("PRNT");
    pnrt = await PNRT.deploy();
    await pnrt.deployed();
    PRNTAddress = pnrt.address;

    const XDCVaultMasternode = await ethers.getContractFactory("XDCVaultMasternodeDiamond");
    xdcDiamond = await XDCVaultMasternode.deploy();
    await xdcDiamond.deployed();
    diamondAddress = xdcDiamond.address;
    console.log("address", diamondAddress);
  });

  it("Should deploy vault facet and add it to the diamond", async function () {
    const VaultFacet = await ethers.getContractFactory("XDCVault");
    vaultContract = await VaultFacet.deploy();
    await vaultContract.deployed();

    const cut = [
      {
        target: vaultContract.address,
        action: 0,
        selectors: getSelectors(vaultContract),
      },
    ];

    const tx = await xdcDiamond.diamondCut(cut, ethers.constants.AddressZero, "0x");
    await tx.wait();

    vaultContract = await ethers.getContractAt("XDCVault", xdcDiamond.address);
    const initTx = await vaultContract.initialize(
      oracleAddress,
      PRNTAddress,
      rewardsDistribution.address,
      "100000000000000000000",
      0,
      500, // rewardRate
      "tokenURI",
      "tokenName",
      "tokenSymbol"
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
    const rewardRate = await getterFacet.getRewardRate();

    expect(rewardRate).to.equal(500);
  });

  it("Should mint NFTs and validate the requirement", async function () {
    await pnrt.mint(user.address, "200000000000000000000"); // 2 PRNT
    const balance = await pnrt.balanceOf(user.address);
    expect(balance).to.equal("200000000000000000000");

    await vaultContract.connect(user).safeMint();
    const balanceNFT = await vaultContract.balanceOf(user.address);
    const ownerOf1 = await vaultContract.ownerOf(1);

    expect(ownerOf1).to.equal(user.address);
    expect(balanceNFT).to.equal(1);
    const reward = await getterFacet.getRewardRate();
    expect(reward).to.equal(500);
  });

  it("Should notify reward amount to start and make Stake", async function () {
    const tx = await vaultContract.connect(rewardsDistribution).notifyRewardAmount(
      ethers.utils.parseEther("100"),
      5184000,
      { value: ethers.utils.parseEther("100") }
    );
    await tx.wait();

    await vaultContract.connect(user).stake(1, ethers.utils.parseEther("300"), {
      value: ethers.utils.parseEther("300"),
    });
  });

  it("Should advance in time and receive rewards", async function () {
    let earned = await vaultContract.earned(1);
    console.log(`Earned before time advance: ${earned.toString()}`);

    const currentBlock = await ethers.provider.getBlock("latest");
    const currentTime = currentBlock.timestamp;
    const daysToAdvance = 30 * 24 * 60 * 60; // 30 days

    await ethers.provider.send("evm_increaseTime", [daysToAdvance]);
    await ethers.provider.send("evm_mine", []);

    const newBlock = await ethers.provider.getBlock("latest");
    const newTime = newBlock.timestamp;

    expect(newTime).to.be.closeTo(currentTime + daysToAdvance, 2);

    let balanceBeforeInStake = await getterFacet.getNFTData(1);
    const tx = await vaultContract.connect(user).getReward(1);
    let balanceAfterInStake = await getterFacet.getNFTData(1);

    expect(balanceAfterInStake.staked).to.be.gt(balanceBeforeInStake.staked);

    earned = await vaultContract.earned(1);
    console.log(`Earned after claiming rewards: ${earned.toString()}`);
  });

  it("Should not allow staking other than the owner", async function () {
    await expect(
      vaultContract.connect(otroUser).stake(1, ethers.utils.parseEther("50"), { value: ethers.utils.parseEther("50") })
    ).to.be.revertedWith("NotOwner");
  });

  it("Should emit Staked event on successful stake", async function () {
    const tx = await vaultContract.connect(user).stake(1, ethers.utils.parseEther("100"), { value: ethers.utils.parseEther("100") });
    await expect(tx)
      .to.emit(vaultContract, "StakeInNFT")
      .withArgs(user.address, 1, ethers.utils.parseEther("100"));
  });

  it("Should allow the user to burn and redeem both staked tokens and rewards", async function () {
    await vaultContract.connect(user).stake(1, ethers.utils.parseEther("300"), {
      value: ethers.utils.parseEther("300"),
    });

    const daysToAdvance = 30 * 24 * 60 * 60; // 30 days
    await ethers.provider.send("evm_increaseTime", [daysToAdvance]);
    await ethers.provider.send("evm_mine", []);

    const tx = await vaultContract.connect(user).burnAndRedeem(1);
    await tx.wait();

    const balanceNFT = await getterFacet.balanceOfStake(1);
    const nftData = await getterFacet.getNFTData(1);
    expect(nftData.staked).to.equal(0);
    expect(balanceNFT).to.equal(0);
  });

  it("Should correctly update balances after staking and exiting", async function () {
    const balanceBeforeStake = await ethers.provider.getBalance(user.address);
    await vaultContract.connect(user).safeMint();
    await vaultContract.connect(user).stake(2, ethers.utils.parseEther("300"), {
      value: ethers.utils.parseEther("300"),
    });

    const tx = await vaultContract.connect(user).burnAndRedeem(2);
    await tx.wait();

    const balanceAfterExit = await ethers.provider.getBalance(user.address);
    expect(balanceAfterExit).to.be.gt(balanceBeforeStake.sub(ethers.utils.parseEther("300")));
  });

  it("Should allow only rewardsDistribution to notify new rewards", async function () {
    await vaultContract.connect(rewardsDistribution).notifyRewardAmount(
      ethers.utils.parseEther("100"),
      2592000,
      { value: ethers.utils.parseEther("100") }
    );

    await expect(
      vaultContract.connect(user).notifyRewardAmount(
        ethers.utils.parseEther("50"),
        2592000,
        { value: ethers.utils.parseEther("50") }
      )
    ).to.be.revertedWith("NotRewardDistribution()");

    await expect(
      vaultContract.connect(rewardsDistribution).notifyRewardAmount(
        ethers.utils.parseEther("50"),
        1000,
        { value: ethers.utils.parseEther("50") }
      )
    ).to.be.revertedWith("CannotReducePeriod()");
  });

  it("Should handle multiple users staking simultaneously", async function () {
    await pnrt.mint(user.address, ethers.utils.parseEther("200"));
    await pnrt.mint(rewardsDistribution.address, ethers.utils.parseEther("200"));

    await vaultContract.connect(user).safeMint();
    await vaultContract.connect(rewardsDistribution).safeMint();

    await vaultContract.connect(user).stake(3, ethers.utils.parseEther("100"), { value: ethers.utils.parseEther("100") });
    await vaultContract.connect(rewardsDistribution).stake(4, ethers.utils.parseEther("150"), { value: ethers.utils.parseEther("150") });

    const balanceUser = await vaultContract.balanceOf(user.address);
    const balanceRewards = await vaultContract.balanceOf(rewardsDistribution.address);

    expect(balanceUser).to.equal(1);
    expect(balanceRewards).to.equal(1);
  });
});
