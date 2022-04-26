const CrossPunksDex = artifacts.require("CrossPunksDex");

module.exports = function (deployer) {
  deployer.then(async () => {

    await deployer.deploy(CrossPunksDex, "0x4Ec6EcDB282429813805cE628F4e48B86849fb23");
});
};
