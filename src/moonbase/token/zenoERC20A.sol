// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "solmate@6.2.0/src/tokens/ERC20.sol";
import {Owned} from "solmate@6.2.0/src/auth/Owned.sol";

contract zeno is ERC20,Owned {
   
    event BridgeMint(address indexed _user,  uint256 _amount);
    event BridgeBurn(address indexed _user,  uint256 _amount);

    address internal bridge;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        address _deployer
    )ERC20(_name,_symbol,_decimals) Owned(_deployer) {
        _mint(_deployer, _initialSupply);
    }


    function revokeApprove(address spender) public  returns (bool) {
        delete allowance[msg.sender][spender];
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function getChainId() public view  returns (uint256) {
        return INITIAL_CHAIN_ID;
    }

    /*//////////////////////////////////////////////////////////////
                        BRIDGE LOGIC
    //////////////////////////////////////////////////////////////*/

    function getBridge() public view returns (address) {
        return bridge;
    }

    function setBridge(address bridge_) external onlyOwner() returns (address) {
        bridge=bridge_;
        return bridge;
    }

    function bridgeMint (address _user, uint256 _amount) external onlyBridge() returns (bool){
       _mint(_user, _amount);
       emit BridgeMint(_user, _amount);
       return true;
   }

    function bridgeBurn (address _user, uint256 _amount) external onlyBridge()returns (bool) {
       _burn(_user,_amount);
       emit BridgeBurn(_user, _amount);
       return true;
   }

    modifier onlyBridge() {
        if (msg.sender != bridge) {
            revert();
        }
        _;
    }

}