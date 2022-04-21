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
        await this.cst.mint(ref, 10000000000, {from: owner});
        await this.cst.mint(recipient, 10000000000, {from: owner});
        await this.cp.finishInitilizeOwners({ from: owner });
        await this.nftCollection.finishInitilizeOwners({ from: owner });
        await this.cp.mintNFT(10, { from: recipient, value: ether('1') });
        await this.nftCollection.mintNFT(10, { from: ref, value: ether('1') });
    });

    it('offer and Sale NFT', async () => {
        var temp = await this.cp.tokenOfOwnerByIndex(recipient, 0);
        var tempId = await this.nftCollection.tokenOfOwnerByIndex(ref, 0);

        await this.cp.approve(this.crossPunksDex.address, temp.toNumber(), {from: recipient});
        await this.nftCollection.approve(this.crossPunksDex.address, tempId.toNumber(), {from: ref});

        await expectRevert(this.crossPunksDex.offerForSale(this.nftCollection.address, tempId.toNumber(), 1000, {from: ref}), "NFT not correct");
        await this.crossPunksDex.editWhiteList(this.nftCollection.address, true);

        await this.crossPunksDex.offerForSale(this.cp.address, temp.toNumber(), 1000, {from: recipient});
        await this.crossPunksDex.offerForSale(this.nftCollection.address, tempId.toNumber(), 1000, {from: ref});
        
        await this.cst.approve(this.crossPunksDex.address, 1000, {from: recipient})
        await this.cst.approve(this.crossPunksDex.address, 1000, {from: ref})

        await this.crossPunksDex.buyNft(this.cp.address, temp.toNumber(), {from: ref});
        await this.crossPunksDex.buyNft(this.nftCollection.address, tempId.toNumber(), {from: recipient});
        
        await expect((await this.cst.balanceOf(this.crossPunksDex.address)).toNumber()).equal(100);
        await expect((await this.cst.balanceOf(recipient)).toNumber()).equal(9999999950);
        await expect((await this.cp.tokenOfOwnerByIndex(ref, 0)).toNumber()).equal(temp.toNumber());
        await expect((await this.cst.balanceOf(ref)).toNumber()).equal(9999999950);
        await expect((await this.nftCollection.tokenOfOwnerByIndex(recipient, 0)).toNumber()).equal(tempId.toNumber());

        await this.crossPunksDex.comissionToOwner();
        await expect((await this.cst.balanceOf(this.crossPunksDex.address)).toNumber()).equal(0);
    });

    it('offer, close', async () => {

        var temp = await this.cp.tokenOfOwnerByIndex(recipient, 0);

        await this.cp.approve(this.crossPunksDex.address, temp.toNumber(), {from: recipient});
        await this.crossPunksDex.offerForSale(this.cp.address, temp.toNumber(), 1000, {from: recipient});
        await expectRevert(this.crossPunksDex.withdrawNft(this.cp.address, temp.toNumber(), { from: ref }), 'Only Owner');
        await this.crossPunksDex.withdrawNft(this.cp.address, temp.toNumber(), {from: recipient});
    });
    
});
