const { BN, expectRevert, ether } = require('@openzeppelin/test-helpers');

const CarsNFT = artifacts.require('CarsNFT');
const MockERC20 = artifacts.require('MockedERC20');

contract('CarsNFT', async (accounts) => {
    const owner = accounts[0];
    const recipient = accounts[1];
    const router = accounts[2];

    describe('has correct', async () => {
        beforeEach(async () => {
            this.busd = await MockERC20.new("BUSD", "BUSD", { from: owner });
            this.cst = await MockERC20.new("CrossToken", "CST", { from: owner });

            await this.busd.mint(owner, ether('300000'), { from: owner });
            await this.cst.mint(owner, ether('55000000'), { from: owner });

            await this.busd.transfer(recipient, ether('100000'), { from: owner });

            this.tech = await CarsNFT.new("Technomaniacs", "TECH", this.busd.address, this.cst.address, router, { from: owner });
            this.awo = await CarsNFT.new("Awokensages", "AWO", this.busd.address, this.cst.address, router, { from: owner });

            await this.busd.approve(this.tech.address, ether('100000'), { from: owner });
            await this.busd.approve(this.tech.address, ether('100000'), { from: recipient });
        });

        it('has correct NFT', async () => {
            const nameTech = await this.tech.name();
            assert.equal(nameTech, "Technomaniacs");

            const symbolTech = await this.tech.symbol();
            assert.equal(symbolTech, "TECH");

            const nameAwo = await this.awo.name();
            assert.equal(nameAwo, "Awokensages");

            const symbolAwo = await this.awo.symbol();
            assert.equal(symbolAwo, "AWO");

            const totalSupply = await this.tech.totalSupply();
            assert.equal(totalSupply, 0);
        });

        it('has correct mint 1 NFT', async () => {
            await expectRevert(this.tech.mintNFT(1, { from: recipient }), 'Sale is not start');

            await this.tech.finishInitilizeOwners({ from: owner });

            // Reverts
            await expectRevert(this.tech.mintNFT(0, { from: recipient }), 'numberOfNfts cannot be 0');
            await expectRevert(this.tech.mintNFT(21, { from: recipient }), 'You may not buy more than 20 NFTs at once');

            await this.tech.mintNFT(1, { from: recipient });

            const balance = await this.tech.balanceOf(recipient);
            assert.equal(balance, 1);

            const balanceTech = await this.busd.balanceOf(this.tech.address);
            assert.equal(balanceTech, '9990000000000000000');

            const totalSupply = await this.tech.totalSupply();
            assert.equal(totalSupply, 1);
        });

        it('has correct mint 5 NFT', async () => {
            await this.tech.finishInitilizeOwners({ from: owner });

            await this.tech.mintNFT(5, { from: recipient });

            const balance = await this.tech.balanceOf(recipient);
            assert.equal(balance, 5);

            const balanceTech = await this.busd.balanceOf(this.tech.address);
            assert.equal(balanceTech, '49950000000000000000');

            const totalSupply = await this.tech.totalSupply();
            assert.equal(totalSupply, 5);
        });
    });
});
