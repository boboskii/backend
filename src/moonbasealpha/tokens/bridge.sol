// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

interface Itoken {
   function allowance(address owner, address spender) external view returns (uint256);
   function setBridge(address _bridge) external returns (bool);
   function bridgeMint (address _to, uint256 _amount) external returns (bool);
   function bridgeBurn (address _from, uint256 _amount) external returns (bool);
}

contract bridgeV1 is Ownable{
    // 状态变量和proxy合约一致，防止插槽冲突
    address public implementation; 
    Itoken  immutable token;
    event Upgrade(address indexed newImplementation);


  constructor(address newOwner ,address _token) Ownable(newOwner) {
    token=Itoken(_token);
    }


    function brigeToken() external {
    }

    // UUPS中，逻辑函数中必须包含升级函数，不然就不能再升级了。
    function upgrade(address newImplementation) external onlyOwner() {
       token.setBridge(newImplementation);
        implementation = newImplementation;
       emit Upgrade(newImplementation);
    }

}