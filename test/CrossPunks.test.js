const { BN, expectRevert, ether } = require('@openzeppelin/test-helpers');
const { web3 } = require('@openzeppelin/test-helpers/src/setup');

const CrossPunks = artifacts.require('CrossPunks');

contract('CrossPunks', (accounts) => {
    const owner = accounts[0];
    const recipient = accounts[1];
    const ref = accounts[2];

    beforeEach(async () => {
        this.cp = await CrossPunks.new("CrossPunks", "CP", { from: owner });
    });

    it('has correct NFT', async () => {
        const name = await this.cp.name();
        assert.equal(name, "CrossPunks");

        const symbol = await this.cp.symbol();
        assert.equal(symbol, "CP");
    });

    it('has correct mint 1 NFT', async () => {
        await expectRevert(this.cp.mintNFT(1, { from: recipient, value: ether('0.1') }), 'Sale is not start');

        await this.cp.finishInitilizeOwners({ from: owner });

        // Reverts
        await expectRevert(this.cp.mintNFT(0, { from: recipient, value: ether('0.1') }), 'numberOfNfts cannot be 0');
        await expectRevert(this.cp.mintNFT(21, { from: recipient, value: ether('0.1') }), 'You may not buy more than 20 NFTs at once');
        await expectRevert(this.cp.mintNFT(1, { from: recipient, value: ether('0.01') }), 'BNB value sent is not correct');

        const balanceOwner = await web3.eth.getBalance(owner);

        await this.cp.mintNFT(1, { from: recipient, value: ether('0.1') });

        const balance = await this.cp.balanceOf(recipient);
        assert.equal(balance, 1);

        const newBalanceOwner = await web3.eth.getBalance(owner);
        assert.equal(newBalanceOwner, new BN(balanceOwner).add(ether('0.1')));
    });

    it('has correct mint 5 NFT', async () => {
        await this.cp.finishInitilizeOwners({ from: owner });

        const balanceOwner = await web3.eth.getBalance(owner);

        await this.cp.mintNFT(5, { from: recipient, value: ether('0.5') });

        const balance = await this.cp.balanceOf(recipient);
        assert.equal(balance, 5);

        const newBalanceOwner = await web3.eth.getBalance(owner);
        assert.equal(newBalanceOwner, new BN(balanceOwner).add(ether('0.5')));
    });

    it('has correct mintNFTAirDrop 1 NFT', async () => {
        await expectRevert(this.cp.mintNFTAirDrop(1, 1000, { from: recipient, value: ether('0.1') }), 'Sale is not start');

        await this.cp.finishInitilizeOwners({ from: owner });

        const id = 1000;
        await this.cp.startAirDrop({ from: ref });

        // Reverts
        await expectRevert(this.cp.mintNFTAirDrop(0, id, { from: recipient, value: ether('0.1') }), 'numberOfNfts cannot be 0');
        await expectRevert(this.cp.mintNFTAirDrop(21, id, { from: recipient, value: ether('0.1') }), 'You may not buy more than 20 NFTs at once');
        await expectRevert(this.cp.mintNFTAirDrop(1, id, { from: recipient, value: ether('0.01') }), 'BNB value sent is not correct');
        const balanceOwner = await web3.eth.getBalance(owner);
        const balanceRef = await web3.eth.getBalance(ref);

        await this.cp.mintNFTAirDrop(1, id, { from: recipient, value: ether('0.1') });
        console.log("Here1")

        const balance = await this.cp.balanceOf(recipient);
        assert.equal(balance, 1);
        console.log("Here2")

        const newBalanceOwner = await web3.eth.getBalance(owner);
        assert.equal(newBalanceOwner, new BN(balanceOwner).add(ether('0.09')));
        console.log("Here3")

        const newBalanceRef = await web3.eth.getBalance(ref);
        assert.equal(newBalanceRef, new BN(balanceRef).add(ether('0.01')));
        console.log("Here4")

    });

    it('has correct mintNFTAirDrop 5 NFT', async () => {
        await this.cp.finishInitilizeOwners({ from: owner });

        const id = 1000;
        await this.cp.startAirDrop({ from: ref });

        const balanceOwner = await web3.eth.getBalance(owner);
        const balanceRef = await web3.eth.getBalance(ref);

        await this.cp.mintNFTAirDrop(5, id, { from: recipient, value: ether('0.5') });

        const balance = await this.cp.balanceOf(recipient);
        assert.equal(balance, 5);

        const newBalanceOwner = await web3.eth.getBalance(owner);
        assert.equal(newBalanceOwner, new BN(balanceOwner).add(ether('0.45')));

        const newBalanceRef = await web3.eth.getBalance(ref);
        assert.equal(newBalanceRef, new BN(balanceRef).add(ether('0.05')));
    });

    it('has correct id airDrop', async () => {
        const id = await this.cp.startAirDrop.call({ from: ref });
        assert.equal(id, 1000);
    })
});
