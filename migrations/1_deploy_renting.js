const Renting = artifacts.require('Renting');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  deployer.deploy(Renting);
};