// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import {Ownable} from "@solady/auth/Ownable.sol";

interface Itoken {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function bridgeMint(address to_, uint256 amount_) external returns (bool);

    function bridgeBurn(address from_, uint256 amount_) external returns (bool);
}

interface IBridgeRouter {

    event remoteMinted(uint256 indexed chainId, address indexed tokenAddress, uint256 amount);

    function remoteMint(
        string calldata destinationChain_,
        string calldata destinationAddress_,
        string calldata amount_
    ) external;

}


contract bridge is Ownable {
    Itoken private token;
    IBridgeRouter private bridgeRouter;

    event TokenBridged(
        uint256 indexed chainId,
        address indexed user,
        uint256 amount
    );

    constructor(address newOwner_) {
        _initializeOwner(newOwner_);
    }

    function setTokenAddress(address token_) external onlyOwner {
        token = Itoken(token_);
    }

    function getTokenAddress() external view returns (address) {
        return address(token);
    }

    function setBridgeRouter(address bridgeRouter_) external onlyOwner {
        bridgeRouter = IBridgeRouter(bridgeRouter_);
    }

    function getBridgeRouter() external view returns (address) {
        return address(bridgeRouter);
    }

    function brigeToken(
        string calldata destinationChain_,
        address destinationAddress_,
        uint256 amount_
    ) external {
        uint256 amount = token.allowance(msg.sender, address(this));
        require(amount > 0, "must be greater than 0");
        token.bridgeBurn(msg.sender, amount_);
        bridgeRouter.remoteMint(destinationChain_, destinationAddress_,amount_);
    }

    function completeBridgeToken(
        uint256 chainId,
        address tokenAddress,
        uint256 amount
    ) internal {
        require(msg.sender == address(bridgeRouter), "only bridgeRouter");
        token.bridgeMint(msg.sender, amount);
        emit TokenBridged(chainId, msg.sender, amount);
    }



}
