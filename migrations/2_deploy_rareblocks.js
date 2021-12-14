const RareBlocks = artifacts.require('RareBlocks');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  deployer.deploy(RareBlocks);
};