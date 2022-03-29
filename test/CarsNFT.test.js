const { BN, expectRevert, ether } = require('@openzeppelin/test-helpers');

const CarsNFT = artifacts.require('CarsNFT');
const MockERC20 = artifacts.require('MockedERC20');

// const UniswapV2Pair = artifacts.require('UniswapV2Pair');
const UniswapV2Router02 = artifacts.require('UniswapV2Router02');
const UniswapV2Factory = artifacts.require('UniswapV2Factory');

contract('CarsNFT', async (accounts) => {
    const owner = accounts[0];
    const recipient = accounts[1];

    describe('has correct', async () => {
        beforeEach(async () => {
            // Create tokens
            this.usdt = await MockERC20.new("USDT", "USDT", { from: owner });
            this.busd = await MockERC20.new("BUSD", "BUSD", { from: owner });
            this.cst = await MockERC20.new("CrossToken", "CST", { from: owner });

            // Mint tokens
            await this.usdt.mint(owner, ether('10000000.0'), { from: owner });
            await this.busd.mint(owner, ether('300000'), { from: owner });
            await this.cst.mint(owner, ether('55000000'), { from: owner });

            // Create Uniswap or Pancakeswap
            this.factory = await UniswapV2Factory.new(owner, { from: owner });
            this.router = await UniswapV2Router02.new(
                this.factory.address,
                this.usdt.address,
                { from: owner },
            );

            await this.busd.transfer(recipient, ether('100000'), { from: owner });

            // Create NFT's
            this.tech = await CarsNFT.new("Technomaniacs", "TECH", this.busd.address, this.cst.address, this.router.address, { from: owner });
            this.awo = await CarsNFT.new("Awokensages", "AWO", this.busd.address, this.cst.address, this.router.address, { from: owner });

            // Approve mint
            await this.busd.approve(this.tech.address, ether('100000'), { from: owner });
            await this.busd.approve(this.tech.address, ether('100000'), { from: recipient });

            // Approve for Router
            await this.busd.approve(this.router.address, ether('100000'), { from: owner });
            await this.cst.approve(this.router.address, ether('100000'), { from: owner });
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

        it('has correct swap and add liquidity', async () => {
            // Create pair
            const pair = await this.factory.createPair(this.busd.address, this.cst.address, { from: owner });
            const pairAddress = pair.logs[0].args.pair;

            // Add liquidity
            let deadline = Math.round(new Date().getTime() / 1000) + 3600;
            await this.router.addLiquidity(this.busd.address, this.cst.address, ether('1000'), ether('1000'), 0, 0, owner, deadline, { from: owner });

            // Check balances pair
            let balancePairBUSD = await this.busd.balanceOf(pairAddress);
            assert.equal(balancePairBUSD, '1000000000000000000000');

            let balancePairCST = await this.cst.balanceOf(pairAddress);
            assert.equal(balancePairCST, '1000000000000000000000');

            // Check balance tech
            let balanceCST = await this.cst.balanceOf(this.tech.address);
            assert.equal(balanceCST, 0);

            // Mint
            await this.tech.finishInitilizeOwners({ from: owner });
            await this.tech.mintNFT(20, { from: recipient });

            // Swap
            deadline = Math.round(new Date().getTime() / 1000) + 3600;
            await this.tech.swapBUSDForCST(ether('50'), 0, deadline, { from: owner });

            balanceCST = await this.cst.balanceOf(this.tech.address);
            assert(0 < balanceCST < ether('50'));

            // Add liquidity
            deadline = Math.round(new Date().getTime() / 1000) + 3600;
            await this.tech.addLiquidity(ether('10'), ether('10'), 0, 0, deadline, { from: owner });

            // Check balances pair
            balancePairBUSD = await this.busd.balanceOf(pairAddress);
            balancePairCST = await this.cst.balanceOf(pairAddress);

            assert.equal(balancePairBUSD, '1060000000000000000000');
            assert.equal(balancePairCST, '961588616967956873657');
        });
    });
});
