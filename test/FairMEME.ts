import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, {ethers} from "hardhat";

describe("FairMEME", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    const [deployer,tradeFeeReceiver,protocolReceiver,] = await ethers.getSigners()
    console.log('deployer address: ' + deployer.address);

    const chainId = (await ethers.provider.getNetwork()).chainId.toString();
    console.log("deployed chainId: ", chainId);

    const MockSwapFactory = await ethers.getContractFactory("MockSwap");
    const MockSwap = await MockSwapFactory.deploy();
    await MockSwap.waitForDeployment();
    console.log("MockSwap address: ", MockSwap.target);

    const FairMEME20Factory = await ethers.getContractFactory("FairMEME20");
    let defaultMintConfigParam = {
      mintSupply: ethers.parseEther("1000.0").toString(),
      mintPrice: ethers.parseEther("0.1").toString(),
      singleMintMin: ethers.parseEther("1.0").toString(),
      singleMintMax: ethers.parseEther("1000.0").toString(),
      mintMax: ethers.parseEther("1000.0").toString(),
      endTimestamp: 20150111818818,
      liquidityPrice:ethers.parseEther("0.12").toString(),
    }

    let defaultTradeConfigParam = {
      swapRouter: MockSwap.target,
    };
    const FairMEME20 = await FairMEME20Factory.deploy("meme","MEME",18,defaultMintConfigParam,defaultTradeConfigParam,protocolReceiver);
    await FairMEME20.waitForDeployment();
    return { FairMEME20,deployer,protocolReceiver,MockSwap};
  }

  describe("Fair mint", function () {

    it("Should set the right trade step", async function () {
      const { FairMEME20 } = await loadFixture(deployFixture);

      expect(await FairMEME20.tradeStep()).to.equal(0);
    });
    it("Fair mint", async function () {
      const { FairMEME20,deployer,MockSwap } = await loadFixture(deployFixture);
      let fairMintTransaction = await FairMEME20.fairMint(ethers.parseEther("1000.0").toString(),{value:ethers.parseEther("100.0").toString()})
      await fairMintTransaction.wait();
      expect(await FairMEME20.balanceOf(deployer)).to.equal(ethers.parseEther("1000.0").toString());
      expect(await FairMEME20.tradeStep()).to.equal(2);

      console.log("mockSwap balance of ", ethers.formatEther((await FairMEME20.balanceOf(MockSwap)).toString()))
      console.log("getContactBalance ", ethers.formatEther(await FairMEME20.getContactBalance()))

    });
    it("Fair mint revert", async function () {
      const { FairMEME20,deployer } = await loadFixture(deployFixture);
      let fairMintTransaction = await FairMEME20.fairMint(ethers.parseEther("1000.0").toString(),{value:ethers.parseEther("100.0").toString()})
      await fairMintTransaction.wait();
      expect(await FairMEME20.balanceOf(deployer)).to.equal(ethers.parseEther("1000.0").toString());
      await expect( FairMEME20.fairMint(ethers.parseEther("100.0").toString(),{value:ethers.parseEther("10.0").toString()})).to.be.revertedWith("not fair mint")
    });

    it("Fair mint and max mint revert", async function () {
      const { FairMEME20,deployer } = await loadFixture(deployFixture);
      let fairMintTransaction = await FairMEME20.fairMint(ethers.parseEther("100.0").toString(),{value:ethers.parseEther("10.0").toString()});
      await fairMintTransaction.wait();
      // expect(await FairMEME20.balanceOf(deployer)).to.equal(ethers.parseEther("100.0").toString());

      await expect( FairMEME20.fairMint(ethers.parseEther("1000.0").toString(),{value:ethers.parseEther("100.0").toString()})).to.be.revertedWith('total exceed mintMax');

    });


  });
});
