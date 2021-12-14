// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RareBlocksInterface {
    function safeTransferFrom(address from, address to, uint256 tokenId) virtual external;
}

contract Renting is IERC721Receiver, Ownable{

    RareBlocksInterface rareBlocks;

    struct Stake {
        uint256 tokenId;
        address owner;
        bool isRentable;
        uint256 price; 
    }

    struct Rent {
        uint256 tokenId;
        address renter;
        uint80 rentEndDate;
    }

    uint[] rentableTokens; // List of tokens that can be rented

    address treasuryAddress = 0x1bCbbd7f9415768338f92A9B8758fa4ABeE4FFD0; // Treasury

    mapping(uint256 => Stake) stakes; // Track staked tokens
    mapping(uint256 => Rent) rents; // Track rented tokens
    mapping(address => uint256) renterToToken; // Track rented token for address
    mapping(address => uint256) rentBalance; // Track rent balance payable to token holder


    event Rented(address indexed _address, uint256 tokenId); // Renting event

    // Set RarBlocks contract address
    function setRareblocksContractAddress(address _rbAddress) public onlyOwner{
        rareBlocks = RareBlocksInterface(_rbAddress);
    }

    // Function called when being transfered a ERC721 token
    // On receival add staking information to struct Stake
    function onERC721Received(address from,  address,  uint256 tokenId,  bytes calldata )external returns(bytes4) {
        stakes[tokenId] = Stake({
            tokenId: tokenId,
            owner: from,
            isRentable: true,
            price: 1 ether
        });

        addToRentableTokensArray(tokenId); // Add to array where we track rentable tokenIds

        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    } 

    // Get Stake[id] data
    function getStakeDataForId(uint256 id) public view returns (uint256, address, bool) {
        require(stakes[id].owner != address(0), "This tokenId is not staked");
        return (stakes[id].tokenId, stakes[id].owner, stakes[id].isRentable);
    }

    // Unstake ERC721 token and return back to person who staked it.
    function unstakeAccessPass(uint256 id) public {
        require(stakes[id].owner == msg.sender, "You do not own this Access Pass.");
        require(rents[id].renter == address(0), "This is pass is still rented out.");
        rareBlocks.safeTransferFrom(address(this), msg.sender, id);
        delete stakes[id];
        removeFromRentableTokensArrayById(id); // Remove from array where we track rentable tokenIds
    }

    function rent(address renter, uint256 tokenId) public payable {
        require(stakes[tokenId].owner != address(0), "This token is not staked.");
         // Remove mapping for expired rent
        if(rents[tokenId].rentEndDate < block.timestamp){
            delete rents[tokenId];
            delete renterToToken[rents[tokenId].renter];
        }

        require(rents[tokenId].renter == address(0), "This token is already rented out.");
        require(stakes[tokenId].price == msg.value, "Not enough ether send to pay for rent.");
        require(stakes[tokenId].isRentable, "This token is set to non-rentable.");

       
        // @TODO Check if address is already renting a token

        // Map rent information
        rents[tokenId] = Rent({
            tokenId: tokenId,
            renter: renter,
            rentEndDate: uint80(block.timestamp + 30 days)
        });

        // Map address to tokenId
        renterToToken[renter] = tokenId;

        // Map rent balance to staker
        rentBalance[stakes[tokenId].owner] = msg.value;

        emit Rented(renter, tokenId);
    }

    function getWalletRentStatus(address renter) public view returns (uint256, address, uint80) {
        uint256 id = renterToToken[renter];
        require(rents[id].renter != address(0), "This address has not rented a token");
        return (rents[id].tokenId, rents[id].renter, rents[id].rentEndDate);
    }

    function getRentBalance(address staker) public view returns (uint256){
        return rentBalance[staker];
    }

    function withdrawRentBalance() public{       
        uint balance = rentBalance[msg.sender];
        require(balance > 0, "You do not have any rent");
        payable(msg.sender).transfer(balance * 90 / 100); // 90% - Pass Holder
        payable(treasuryAddress).transfer((balance * 10) / 100);  // 10% - Treasury
    }

    function getListOfRentableTokens() public view returns(uint[] memory, uint[] memory, uint[] memory){
        require(rentableTokens.length > 0, "No tokens are listed");
        uint[] memory tokenId = new uint[](rentableTokens.length);
        uint[] memory price = new uint[](rentableTokens.length); 
        uint[] memory rentEndDate = new uint[](rentableTokens.length); 

        for (uint256 i = 0; i < rentableTokens.length; i++){
            if(stakes[rentableTokens[i]].isRentable){ // Check if token is rentable
                tokenId[i] = rentableTokens[i];
                price[i] = stakes[rentableTokens[i]].price;
                rentEndDate[i] = rents[rentableTokens[i]].rentEndDate;
            }
        }
        return (tokenId, price, rentEndDate);
    }


    // Change the price of a staked tokenId
    function setPrice(uint256 _tokenId, uint256 _price) public{
        require(stakes[_tokenId].owner != address(0), "This token is not staked.");
        require(stakes[_tokenId].owner == msg.sender, "You do not own this token!");
        stakes[_tokenId].price = _price;
    }

    // Toggle isRentable. If isRentable is false, this pass cannot be rented anymore, meaning it will be able to unstake.
    function toggleIsRentable(uint256 _tokenId) public{
        require(stakes[_tokenId].owner != address(0), "This token is not staked.");
        require(stakes[_tokenId].owner == msg.sender, "You do not own this token!");
        stakes[_tokenId].isRentable = !stakes[_tokenId].isRentable;
    }

    function updateTreasury(address _newAddress) external onlyOwner {
        treasuryAddress = _newAddress;
    }


    // Track rentable tokens by adding them to an array;
    function addToRentableTokensArray(uint256 tokenId) public{
        rentableTokens.push(tokenId);
    }

    function removeFromRentableTokensArrayById(uint256 tokenId) public{
       for (uint256 i = 0; i < rentableTokens.length; i++){
            if(rentableTokens[i] == tokenId){
                removeFromRentableTokensArrayByIndex(i);
            }
        }
    }

    function removeFromRentableTokensArrayByIndex(uint256 _index) public {
        require(_index < rentableTokens.length, "index out of bound");

        for (uint256 i = _index; i < rentableTokens.length - 1; i++) {
            rentableTokens[i] = rentableTokens[i + 1];
        }
        rentableTokens.pop();
    }



}