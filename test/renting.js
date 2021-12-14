const Renting = artifacts.require("Renting");
const RareBlocks = artifacts.require("RareBlocks");
const utils = require("./helpers/utils");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */

contract("RareBlocks", function (accounts) {
  let [alice, bob, charlie] = accounts;
  BigInt.prototype.toJSON = function() {       
    return this.toString()
  }

  let instance;
  beforeEach('should setup the contract instance', async () => {
    instance = await RareBlocks.deployed();
    rentingInstance = await Renting.deployed();
  });
  describe('When deploying the contract, it', () => {

    it("should have an access pass supply of 500", async function () {
      const result = await instance.getAccessPassSupply();
      const supply = result.words[0];
      assert.equal(supply, 500);
    });

    it("should have a price of 0.08 eth", async function () {
      const result = await instance.getPrice();
      const price = result.words[0];
      assert.equal(price, 34078720); // In Ether
    });

    it("should have minted 15 tokens on deploy", async function () {
      const result = await instance.getTokenCount();
      const tokens = result.words[0];
      assert.equal(tokens, 15);
    });

    it("should allow the owner to open the regular mint", async () => {
      await instance.setOpenMintActive(true);
    });

    it("should be able to mint for 0.08Eth", async function () {
      const from = alice;
      const value = 80000000000000000;
      const result = await instance.mint(alice, 1, {from, value});
      assert.equal(result.receipt.status, true)
    });

    it("should show that Alice owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, alice);
    });
  });



  describe('When staking, it', () => {

    it("should send 1 NFT from Alice to Renting Contract", async function () {
      const to = rentingInstance.address; // Renting Contract Address
      const from = alice;
      const tokenId = 16;
      const result = await instance.safeTransferFrom(from, to, tokenId);
    });

    // Send NFT to Staking contract
    it("should show that Renting Contract owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, rentingInstance.address);
    });
    
    it("should show data for stake by tokenId", async function(){
      const result = await rentingInstance.getStakeDataForId(16);
      assert.equal(result[1], alice);
    });

    it("should set Rareblocks contract address", async function(){
      await rentingInstance.setRareblocksContractAddress(instance.address);
    });
    
    it("should unstake NFT back to Alice", async function(){
      await rentingInstance.unstakeAccessPass(16);
    });

    it("should show that Alice owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, alice);
    });

    it("should have deleted staking data for id 16", async function(){
      await utils.shouldThrow(rentingInstance.getStakeDataForId(16))
    });
  
  });

  describe('When renting, it', () => {

    it("should let Alice stake a token", async function () {
      const to = rentingInstance.address; // Renting Contract Address
      const from = alice;
      const tokenId = 16;
      await instance.safeTransferFrom(from, to, tokenId);
    });

    it("should NOT be able to rent a non-staked token", async function(){
      await utils.shouldThrow(rentingInstance.rent(charlie, 20))
    });

    it("should be able to rent a staked token", async function(){
      const result = await rentingInstance.rent(charlie, 16);
      assert.equal(result.logs[0].event, 'Rented');
      assert.equal(result.logs[0].args[0], charlie)
    });
    
    it("should get renting information", async function(){
      const result = await rentingInstance.getWalletRentStatus(charlie);
      console.log(BigInt(result[2]))
    });

    it("should error if not rented for address", async function(){
      await utils.shouldThrow(rentingInstance.getWalletRentStatus(bob));
    });

    it("should NOT be able to unstake NFT back to Alice", async function(){
      await utils.shouldThrow(rentingInstance.unstakeAccessPass(16));
    });
    
  });



});

