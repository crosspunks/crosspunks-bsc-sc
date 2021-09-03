const CrossPunks = artifacts.require('./CrossPunks');
const CrossPunksDex = artifacts.require('./CrossPunksDex');

module.exports = function(deployer) {
    deployer.then(async () => {
        const cp = await deployer.deploy(CrossPunks, "CrossPunks", "CP");
        await deployer.deploy(CrossPunksDex, cp.address);
    });
};
