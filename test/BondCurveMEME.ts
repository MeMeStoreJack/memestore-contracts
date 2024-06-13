import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, {ethers} from "hardhat";

describe("MEME", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    const [deployer,tradeFeeReceiver,protocolReceiver,referrer, upReferrer] = await ethers.getSigners()
    console.log('deployer address: ' + deployer.address);
    console.log('referrer address: ' + referrer.address);
    console.log('upReferrer address: ' + upReferrer.address);

    const chainId = (await ethers.provider.getNetwork()).chainId.toString();
    console.log("deployed chainId: ", chainId);

    const ReferrerStorageFactory = await ethers.getContractFactory("ReferrerStorage");
    const ReferrerStorage = await ReferrerStorageFactory.deploy();
    await ReferrerStorage.waitForDeployment();
    console.log("ReferrerStorage address: ", ReferrerStorage.target);


    const MockSwapFactory = await ethers.getContractFactory("MockSwap");
    const MockSwap = await MockSwapFactory.deploy();
    await MockSwap.waitForDeployment();
    console.log("MockSwap address: ", MockSwap.target);

    const BondCurveMEME20Factory = await ethers.getContractFactory("BondCurveMEME20");


    let defaultTradeConfigParam = {
      swapRouter: MockSwap.target,
      targetAmount: ethers.parseEther("4").toString(),
      tradeA: ethers.parseEther("1.2").toString(),
      // tradeK: 6,
      initBuyValue: ethers.parseEther("0.01").toString(),
      initBuyMaxPercent: 10,
    };
    const BondCurveMEME = await BondCurveMEME20Factory.deploy("meme","MEME",18,defaultTradeConfigParam,tradeFeeReceiver.address,protocolReceiver.address,ReferrerStorage.target, deployer.address, {value: defaultTradeConfigParam.initBuyValue});
    await BondCurveMEME.waitForDeployment();
    console.log("BondCurveMEME address: ", BondCurveMEME.target);

    return { ReferrerStorage, BondCurveMEME,deployer, tradeFeeReceiver,protocolReceiver,MockSwap, referrer, upReferrer};
  }

  describe("referrerStorage", function () {
    it("Should set the right referrerStorage", async function () {
      const { ReferrerStorage, BondCurveMEME } = await loadFixture(deployFixture);

      expect(await BondCurveMEME.referrerStorage()).to.equal(ReferrerStorage.target);
    });

    it("Should set the right trade step", async function () {
      const { ReferrerStorage, BondCurveMEME } = await loadFixture(deployFixture);

      expect(await BondCurveMEME.tradeStep()).to.equal(1);
    });
    it("buy success", async function () {
      const { ReferrerStorage, BondCurveMEME,deployer } = await loadFixture(deployFixture);

      expect(await BondCurveMEME.tradeStep()).to.equal(1);

      let buyTransaction = await BondCurveMEME.buy({value:ethers.parseEther("1").toString()})
      await buyTransaction.wait();
      let balanceBefore = await BondCurveMEME.balanceOf(deployer);
      // for (let i = 0; i < 5; i++) {
      //   let buyTransaction = await BondCurveMEME.buy({value:ethers.parseEther("1").toString()})
      //   await buyTransaction.wait();
      // }
      //
      // console.log("buy balance of ", await BondCurveMEME.balanceOf(deployer))
      // // let balanceBefore = await BondCurveMEME.balanceOf(deployer);
      let buyTransaction1 = await BondCurveMEME.buy({value:ethers.parseEther("1").toString()})
      await buyTransaction1.wait();

      console.log("buy balance of ", await BondCurveMEME.balanceOf(deployer))
      let buyAmount = (await BondCurveMEME.balanceOf(deployer)) - balanceBefore;
      let sellTransaction = await BondCurveMEME.sell(buyAmount)
      await sellTransaction.wait();

      console.log("sell balance of ", ethers.formatEther((await BondCurveMEME.balanceOf(deployer)).toString()))
      console.log("contact balance of ", ethers.formatEther((await BondCurveMEME.getContactBalance()).toString()))

      // let buyTransaction1 = await BondCurveMEME.buy({value:ethers.parseEther("1.0").toString()})
      // await buyTransaction1.wait();

      // console.log("balance of ", await BondCurveMEME.balanceOf(deployer))
      // expect(await BondCurveMEME.tradeStep()).to.equal(2);

    });

    it("Buy batch", async function () {
      const { ReferrerStorage, BondCurveMEME,deployer,MockSwap, protocolReceiver, tradeFeeReceiver, referrer, upReferrer} = await loadFixture(deployFixture);

      await ReferrerStorage.connect(deployer).setReferrer(referrer.address);
      await ReferrerStorage.connect(referrer).setReferrer(upReferrer.address);

      const [referrerOnchain, upReferrerOnchain] = await ReferrerStorage.getReferrers(deployer.address);
      expect(referrerOnchain).to.equal(referrer.address);
      expect(upReferrerOnchain).to.equal(upReferrer.address);

      const referrerEthBefore = await ethers.provider.getBalance(referrer.address);
      const upReferrerEthBefore = await ethers.provider.getBalance(upReferrer.address);
      const protocolReceiverEthBefore = await ethers.provider.getBalance(protocolReceiver.address);
      const tradeFeeReceiverEthBefore = await ethers.provider.getBalance(tradeFeeReceiver.address);

      let totalAmount = BigInt(0);
      let firstPrice = "";
      let lastPrice = "";
      let buyTimes = 0;
      let singleBuyValue = ethers.parseEther("0.01");
      for (let i = 0; i < 450; i++) {
        let balanceBefore = await BondCurveMEME.balanceOf(deployer);
        let buyTransaction = await BondCurveMEME.buy({value:singleBuyValue.toString()})
        await buyTransaction.wait();


        let buyAmount = (await BondCurveMEME.balanceOf(deployer)) - balanceBefore;

        console.log("buyAmount = ",buyAmount);
        lastPrice = ethers.formatEther((ethers.parseEther("10000000000000000") / buyAmount)).toString();

        if (i == 0){
          firstPrice = lastPrice;
        }

        let amount = await BondCurveMEME.getContactBalance()
        console.log("index = "+ i + " buy mint price：="+ lastPrice +"  contract amount ：= "+ ethers.formatEther(amount.toString()));
        totalAmount = totalAmount + amount;

        // console.log("tradeStep =",(await BondCurveMEME.tradeStep()))

        if ((await BondCurveMEME.tradeStep()) != BigInt(1)){
          console.log("tradeStep =",(await BondCurveMEME.tradeStep()))
          buyTimes = i + 1;
          break
        }

      }
      console.log("firstPrice :=", firstPrice)
      console.log("lastPrice :=", lastPrice);
      console.log("times :=", ethers.parseEther(lastPrice)/ ethers.parseEther(firstPrice))

      console.log("MEME balance of deployer:  ", ethers.formatEther(await BondCurveMEME.balanceOf(deployer)));
      console.log("mockSwap balance of ", ethers.formatEther((await BondCurveMEME.balanceOf(MockSwap)).toString()))
      console.log("getContactBalance ", ethers.formatEther(await BondCurveMEME.getContactBalance()))
      console.log("totalAmount(ETH) ", ethers.formatEther(totalAmount.toString()))

      const referrerEthAfter = await ethers.provider.getBalance(referrer.address);
      const referrerProfit = referrerEthAfter - referrerEthBefore;
      const upReferrerEthAfter = await ethers.provider.getBalance(upReferrer.address);
      const upReferrerProfit = upReferrerEthAfter - upReferrerEthBefore;
      const protocolReceiverEthAfter = await ethers.provider.getBalance(protocolReceiver.address);
      const protocolReceiverProfit = protocolReceiverEthAfter - protocolReceiverEthBefore;
      const tradeFeeReceiverEthAfter = await ethers.provider.getBalance(tradeFeeReceiver);
      const tradeFeeReceiverProfit = tradeFeeReceiverEthAfter - tradeFeeReceiverEthBefore;

      expect(referrerProfit * 2n).to.be.closeTo(upReferrerProfit * 3n, 0n);
      expect(referrerProfit * 1000n).to.be.closeTo(BigInt(buyTimes) * 3n * singleBuyValue, 0n);
      expect(upReferrerProfit * 1000n).to.be.closeTo(BigInt(buyTimes) * 2n * singleBuyValue, 0n);
      expect(tradeFeeReceiverProfit * 100n).to.be.closeTo(BigInt(buyTimes) * singleBuyValue, 0n);
      console.log("protocolReceiverProfit: ", protocolReceiverProfit)
    });
  });
});
