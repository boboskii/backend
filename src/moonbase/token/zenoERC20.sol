// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "solady@0.0.145/src/tokens/ERC20.sol";
import {Owned} from "solmate@6.2.0/src/auth/Owned.sol";

contract zenoToken is ERC20,Owned {
   
    event BridgeMint(address indexed _user,  uint256 _amount);
    event BridgeBurn(address indexed _user,  uint256 _amount);

    string internal name_;
    string internal symbol_; 
    address internal bridge_;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address _deployer,
        address _bridge
    )Owned(_deployer) {
        name_ = _name;
        symbol_ = _symbol;
        _mint(_deployer, _initialSupply);
        bridge_ = _bridge;
    }

    function name() public view virtual override returns (string memory) {
        return name_;
    }

    function symbol() public view virtual override returns (string memory) {
        return symbol_;
    }

    function bridge() public view returns (address) {
        return bridge_;
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
        if (msg.sender != bridge_) {
            revert();
        }
        _;
    }

}
