// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IBridgeRouter {

    event remoteMinted(uint256 indexed chainId, address indexed tokenAddress, uint256 amount);

    function remoteMint(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata amount_
    ) external;

}
