// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/interfaces/IAxelarGasService.sol";



contract bridgeRouterAxelar is AxelarExecutable {

    event remoteMinted(uint256 indexed chainId, address indexed tokenAddress, uint256 amount);

    string public message;
    IAxelarGasService public immutable gasService;
    mapping(uint256 => uint256) public nonce; //chainID => nonce
    address private immutable bridge;

    constructor(address gateway_, address gasReceiver_,address bridge_)
        AxelarExecutable(gateway_)
    {
        gasService = IAxelarGasService(gasReceiver_);
        bridge = bridge_;
    }

    // Call this function to update the value of this contract along with all its siblings'.

    function remoteMint(
        string calldata destinationChain_,
        address destinationAddress_,
        uint256 amount_
    ) external payable {

        string calldata destinationAddress = bytes32ToString(bytes32(uint256(destinationAddress_)));

    }
    
    function remoteCall(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata value_
    ) external payable {
        require(msg.value > 0, "Gas payment is required");
        
        bytes memory payload = abi.encode(value_);
        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain,
            destinationAddress,
            payload,
            msg.sender
        );
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload_
    ) internal override {
        // Decode the payload to retrieve the new message value
        (message) = abi.decode(payload_, (string));
        // Check if the new message is "Hello", then respond with "World"
        if (keccak256(abi.encode(message)) == keccak256(abi.encode("Hello"))) {
            gateway.callContract(
                sourceChain_,
                sourceAddress_,
                abi.encode("World")
            );
        }
    }
}