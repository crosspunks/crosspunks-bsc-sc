const { BN, expectRevert, ether } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const CrossPunks = artifacts.require('CrossPunks');
const CST = artifacts.require("MockedERC20");
const CrossPunksDex = artifacts.require("CrossPunksDex")

contract('CrossPunksDex', (accounts) => {
    const owner = accounts[0];
    const recipient = accounts[1];
    const ref = accounts[2];

    beforeEach(async () => {
        this.cst = await CST.new("CFT", "CFT", {from: owner})
        this.cp = await CrossPunks.new("CrossPunks", "CP", { from: owner });
        this.nftCollection = await CrossPunks.new("nftCollection", "NFT", { from: owner });
        this.crossPunksDex = await CrossPunksDex.new(this.cst.address);
        await this.crossPunksDex.editWhiteList(this.cp.address, true);

    });

    it('has correct NFT', async () => {
        await this.cp.finishInitilizeOwners({ from: owner });

        await this.cp.mintNFT(10, { from: recipient, value: ether('1') });

        var temp = await this.cp.tokenByIndex(1);
        console.log(temp.toString());
        await this.cp.approve(this.crossPunksDex.address, temp.toNumber(), {from: recipient});
        await this.crossPunksDex.offerForSale(this.cp.address, temp.toNumber(), 1000, {from: recipient});

    });

});
