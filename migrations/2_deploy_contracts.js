const CrossPunks = artifacts.require('./CrossPunks');
const CrossPunksDex = artifacts.require('./CrossPunksDex');
const CarsNFT = artifacts.require('./CarsNFT');

module.exports = function(deployer) {
    deployer.then(async () => {
        // const cp = await deployer.deploy(CrossPunks, "CrossPunks", "CP");
        // await deployer.deploy(CrossPunksDex, cp.address);

        // Testnet
        // const busd = "0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7";
        // const cst = "0x4Ec6EcDB282429813805cE628F4e48B86849fb23";
        // const router = "0x9ac64cc6e4415144c455bd8e4837fea55603e5c3";

        const busd = "0xe9e7cea3dedca5984780bafc599bd69add087d56";
        const cst = "0x014be200c192bD8366dF781a96cec51B3D9Dcd93";
        const router = "0x10ed43c718714eb63d5aa57b78b54704e256024e";

        await deployer.deploy(CarsNFT, "Technomaniacs", "TECH", busd, cst, router);
        await deployer.deploy(CarsNFT, "Awokensages", "AWO", busd, cst, router);
    });
};
