// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

//import Open Zepplins ERC-20 interface contract and Ownable contract

import {Owned} from "solmate@6.2.0/src/auth/Owned.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.0/token/ERC20/IERC20.sol";

//create a ERC20 faucet contract
// Logic: people can deposit tokens to the faucet contract, and let other users to request some tokens.
contract Faucet is Owned {
    IERC20 private immutable token;
    mapping(address => bool) public requestedAddress;
    uint256 private amountAllowed = 100 * 1e18;

    //when deploying the token contract is given

    constructor(address token_, address owner_) Owned(owner_) {
        token = IERC20(token_); // set token contract
    }

    event SendToken(address indexed Receiver, uint256 indexed Amount);
    event WithdrawToken(address indexed sender, uint256 indexed Amount);

    function amountForClaim() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    //allow users to call the requestTokens function to get tokens
    function freeClaim() external {
        uint256 amount = amountForClaim();
        require(requestedAddress[msg.sender] == false, "Claim once Only!");
        require(token.balanceOf(address(this)) >= amount, "Faucet Empty!");
        token.transfer(msg.sender, amount); // transfer token
        requestedAddress[msg.sender] = true; // record requested
        emit SendToken(msg.sender, amount); // emit event
    }

    // change requested amount by owner
    function setAmount(uint256 _amount) external onlyOwner {
        amountAllowed = _amount;
    }

    // withdraw ERC20 token by owner
    function stopClaim() public onlyOwner {
        uint256 _amount = token.balanceOf(address(this));
        token.transfer(msg.sender, _amount);
        emit WithdrawToken(msg.sender, _amount);
    }
}
