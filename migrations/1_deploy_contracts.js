const RadicalManager = artifacts.require("RadicalManager");
const RadicalToken = artifacts.require("RadicalTokenExample");

module.exports = async function(deployer) {
  const SABLIER_ADDRESS_RINKEBY = "0xc04Ad234E01327b24a831e3718DBFcbE245904CC";
  const DAI_ADDRESS_RINKEBY = "0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa";
  await deployer.deploy(RadicalManager, SABLIER_ADDRESS_RINKEBY, DAI_ADDRESS_RINKEBY);
  await deployer.deploy(RadicalToken, RadicalManager.address, "Radical.Finance Example Token", "RADICAL");
};
