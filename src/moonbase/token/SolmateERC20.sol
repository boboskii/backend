// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "solmate@7.0.0-alpha.3/src/tokens/ERC20.sol";

contract SolmateERC20 is ERC20 {

    address public bridge;

   event BridgeMint(address indexed _to,  uint256 _amount);
   event BridgeBurn(address indexed _from,  uint256 _amount);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply, address deployer,address _bridge) ERC20(_name, _symbol, _decimals) {
        _mint(deployer, initialSupply);
        bridge = _bridge;
    }

    modifier onlyBridge() {
        if (msg.sender != bridge) {
            revert();
        }
        _;
    }
    function setBridge(address _bridge) external onlyBridge() returns (bool) {
        bridge = _bridge;
        return true;
    }

   function bridgeMint (address _to, uint256 _amount) external onlyBridge() returns (bool){
       _mint(_to, _amount);
       emit BridgeMint(_to, _amount);
       return true;
   }

   function bridgeBurn (address _from, uint256 _amount) external onlyBridge()returns (bool) {
       _burn(_from, _amount);
       emit BridgeBurn(_from, _amount);
       return true;
   }


}