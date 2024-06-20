import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners()
    console.log('deployer address: ' + deployer.address);

    const chainId = (await ethers.provider.getNetwork()).chainId.toString();
    console.log("deployed chainId: ", chainId);


    const FairMEME20Factory = await ethers.getContractFactory("FairMEME20");
        let defaultMintConfigParam = {
            mintSupply: ethers.parseEther("1000000.0").toString(),
            mintPrice: ethers.parseEther("0.1").toString(),
            singleMintMin: ethers.parseEther("1.0").toString(),
            singleMintMax: ethers.parseEther("100.0").toString(),
            mintMax: ethers.parseEther("1000.0").toString(),
            endTimestamp: 20150111818818,
            liquidityPrice:ethers.parseEther("0.12").toString(),
        }


        let defaultTradeConfigParam = {
            swapRouter: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        };
        const FairMEME20 = await FairMEME20Factory.deploy("meme","MEME",18,defaultMintConfigParam,defaultTradeConfigParam,"0x5FbDB2315678afecb367f032d93F642f64180aa3");
    await FairMEME20.waitForDeployment();
    console.log("FairMEME20 address: ", FairMEME20.target);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
