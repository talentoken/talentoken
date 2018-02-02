/**
  ______      __           __        __            
 /_  __/___ _/ /__  ____  / /_____  / /_____  ____ 
  / / / __ `/ / _ \/ __ \/ __/ __ \/ //_/ _ \/ __ \
 / / / /_/ / /  __/ / / / /_/ /_/ / ,< /  __/ / / /
/_/  \__,_/_/\___/_/ /_/\__/\____/_/|_|\___/_/ /_/ 
*/

pragma solidity ^0.4.18;

// contract for owner management
contract Owned {
    // Status variable
    address public owner;   // ownser address

    // event when owner changed
    event TransferOwnership(address oldaddr, address newaddr);

    // modifier (owner only)
    modifier onlyOwner() {require(msg.sender == owner);_;}

    // constructor
    function Owned() public {
        owner = msg.sender;
    }
    
    function transferOwnership(address _new) public onlyOwner {
        address oldaddr = owner;
        owner = _new;
        TransferOwnership(oldaddr, owner);
    }
}
