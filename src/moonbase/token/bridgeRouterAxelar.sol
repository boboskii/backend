// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@axelar-network/axelar-gmp-sdk-solidity@5.6.3/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity@5.6.3/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity@5.6.3/contracts/interfaces/IAxelarGasService.sol";

interface IBridge {
    function remoteMintReceiver(
        bytes calldata _payload
    ) external returns (bool);

    function completeBridgeToken(bytes calldata _payload) external;

    function cancelBridgeToken(bytes calldata _payload) external;
}

// 需要creat3 原地址部署
contract bridgeRouterAxelar is AxelarExecutable {
    error InvalidSourceAddress();

    IBridge private immutable bridge;
    IAxelarGasService public immutable gasService;

    constructor(
        address gateway_,
        address gasReceiver_,
        address bridge_
    ) AxelarExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
        bridge = IBridge(bridge_);
    }

    // Call this function to update the value of this contract along with all its siblings'.

    function remoteMint(
        string calldata _destinationChain,
        string calldata _destinationAddress,
        bytes calldata _payload //u64 chainId, u64 nonce, u128 amount
    ) external payable {
        require(msg.value > 0, "Gas payment is required");

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            _destinationChain,
            _destinationAddress,
            _payload,
            msg.sender
        );
        gateway.callContract(_destinationChain, _destinationAddress, _payload);
    }

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(
        string calldata _sourceChain,
        string calldata _sourceAddress,
        bytes calldata _payload
    ) internal override {
        address sourceAddress_ = address(bytes20(bytes(_sourceAddress)));
        if (sourceAddress_ != address(this)) revert InvalidSourceAddress(); //
        uint256 data_ = abi.decode(_payload, (uint256));
        uint256 state_ = data_ & 0xff;
        if (state_ == 1) {
            bool success = bridge.remoteMintReceiver(_payload); //首次发送状态 1
            if (success) {
                data_ =
                    (data_ &
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000) |
                    (block.chainid << 8) |
                    2;
                bytes memory payload_ = abi.encode(data_);
                gateway.callContract(_sourceChain, _sourceAddress, payload_);
            } else {
                data_ =
                    (data_ &
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000) |
                    (block.chainid << 8) |
                    3;
                bytes memory payload_ = abi.encode(data_);
                gateway.callContract(_sourceChain, _sourceAddress, payload_);
            }
        }
        if (state_ == 2) {
            bridge.completeBridgeToken(_payload);
        }

        if (state_ == 2) {
            bridge.completeBridgeToken(_payload);
        }
    }
}
