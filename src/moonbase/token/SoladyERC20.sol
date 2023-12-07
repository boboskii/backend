// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@solady/tokens/ERC20.sol";

contract SoladyERC20 is ERC20 {
    string internal _name;
    string internal _symbol; 
    address internal immutable bridge;
   
   error NotBridge();

   event BridgeMint(address indexed _to,  uint256 _amount);
   event BridgeBurn(address indexed _from,  uint256 _amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        address deployer_,
        address bridge_
    ) {
        _name = name_;
        _symbol = symbol_;
        _mint(deployer_, initialSupply_);
        bridge = bridge_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function getBridgeAddress() public view returns (address) {
        return bridge;
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

    modifier onlyBridge() {
        if (msg.sender != bridge) {
            revert(NotBridge());
        }
        _;
    }


}
