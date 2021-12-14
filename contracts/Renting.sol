// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


abstract contract RareBlocksInterface {
    function safeTransferFrom(address from, address to, uint256 tokenId) virtual external;
}

contract Renting is IERC721Receiver{

    RareBlocksInterface rareBlocks;

    struct Stake {
        uint256 tokenId;
        address owner;
        bool isRentable;
    }

    struct Rent {
        uint256 tokenId;
        address renter;
        uint80 rentEndDate;
    }

    mapping(uint256 => Stake) stakes; // Track staked tokens
    mapping(uint256 => Rent) rents; // Track rented tokens
    mapping(address => uint256) renterToToken; // Track rented token for address

    event Rented(address indexed _address, uint256 tokenId); // Renting event

    // Set RarBlocks contract address
    function setRareblocksContractAddress(address _rbAddress) public{
        rareBlocks = RareBlocksInterface(_rbAddress);
    }

    // Function called when being transfered a ERC721 token
    // On receival add staking information to struct Stake
    function onERC721Received(address from,  address,  uint256 tokenId,  bytes calldata )external returns(bytes4) {
        stakes[tokenId] = Stake({
            tokenId: tokenId,
            owner: from,
            isRentable: true
        });
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
    }

    function rent(address renter, uint256 tokenId) public {
        require(stakes[tokenId].owner != address(0), "This token is not staked.");
        require(rents[tokenId].renter == address(0), "This token is already rented out.");

        // Map rent information
        rents[tokenId] = Rent({
            tokenId: tokenId,
            renter: renter,
            rentEndDate: uint80(block.timestamp + 30 days)
        });

        // Map address to tokenId
        renterToToken[renter] = tokenId;
        
        emit Rented(renter, tokenId);
    }

    function getWalletRentStatus(address renter) public view returns (uint256, address, uint80) {
        uint256 id = renterToToken[renter];
        require(rents[id].renter != address(0), "This address has not rented a token");
        return (rents[id].tokenId, rents[id].renter, rents[id].rentEndDate);
    }
    
}