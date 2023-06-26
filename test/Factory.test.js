const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Factory", function () {
    let factory;
    let owner;
    const masterContractAddress = "0x4d3C5bbe7A45D440dB13a0b94d8976895c306Cca";

    beforeEach(async () => {
        const Factory = await ethers.getContractFactory("Factory");
        factory = await Factory.deploy(masterContractAddress);
        await factory.deployed();

        [owner] = await ethers.getSigners();
    });

    it("should deploy a child contract", async function () {
        const initialChildrenCount = await factory.getChildren();

        await expect(factory.connect(owner).createChild()).to.not.be.reverted;

        const newChildrenCount = await factory.getChildren();
        expect(newChildrenCount.length).to.equal(initialChildrenCount.length + 1);
    });

});