import { ethers } from "hardhat";

async function main() {
    const [deployer] = await ethers.getSigners()
    console.log('deployer address: ' + deployer.address);

    const chainId = (await ethers.provider.getNetwork()).chainId.toString();
    console.log("deployed chainId: ", chainId);


    const ReferrerStorageFactory = await ethers.getContractFactory("ReferrerStorage");
    const ReferrerStorage = await ReferrerStorageFactory.deploy();
    await ReferrerStorage.waitForDeployment();
    console.log("ReferrerStorage address: ", ReferrerStorage.target);

    const BondCurveMEME20Factory = await ethers.getContractFactory("BondCurveMEME20");
        let defaultTradeConfigParam = {
            swapRouter: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            targetAmount: ethers.parseEther("1000").toString(),
            minMintPrice: ethers.parseEther("0.0000000009").toString(),
        };

      const BondCurveMEME20 = await BondCurveMEME20Factory.deploy("meme","MEME",18,defaultTradeConfigParam,"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266","0x5FbDB2315678afecb367f032d93F642f64180aa3",ReferrerStorage.target);
    await BondCurveMEME20.waitForDeployment();
    console.log("BondCurveMEME20 address: ", BondCurveMEME20.target);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
