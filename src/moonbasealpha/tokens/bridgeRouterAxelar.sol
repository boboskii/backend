// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@axelar-gmp-sdk-solidity/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/interfaces/IAxelarGasService.sol";

interface IBridge {

    function remoteMintReceiver(
        bytes calldata payload_
    ) external;

    function completeBridgeToken(
        address user,
        string calldata chain_ ,
        uint256 nonce_ ,
        uint256 amount_
    ) external;
    
    function cancelBridgeToken(
        address user,
        string calldata chain_ ,
        uint256 nonce_ ,
        uint256 amount_
    ) external; 

}


// 需要creat3 原地址部署
contract bridgeRouterAxelar is AxelarExecutable {


    IBridge private immutable bridge;
    IAxelarGasService public immutable gasService;


    constructor(address gateway_, address gasReceiver_,address bridge_)
        AxelarExecutable(gateway_)
    {
        gasService = IAxelarGasService(gasReceiver_);
        bridge = IBridge(bridge_);
    }

    // Call this function to update the value of this contract along with all its siblings'.

    
    function remoteMint(
        string calldata destinationChain_,
        string calldata destinationAddress_,
        bytes payload_ //u64 chainId, u64 nonce, u128 amount
    ) external payable {
        require(msg.value > 0, 'Gas payment is required');      

        gasService.payNativeGasForContractCall{value: msg.value}(
            address(this),
            destinationChain_,
            destinationAddress_,
            payload_,
            msg.sender
        );
        gateway.callContract(destinationChain_, destinationAddress_, payload_);
    }

    // Handles calls created by setAndSend. Updates this contract's value
    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload_
    ) internal override {
        if (sourceAddress_ != address(this)) revert InvalidSourceAddress();//

            (user,value_)= abi.decode(payload_, (address,uint256));    
            uint256 success_ = value_ >> 224;
        if (success_ == 1) {
            uint256 nonce_ = (value_ >> 128) & 0xffffffffffffffff;
            uint256 amount_ = value_ & 0xffffffffffffffffffffffffffffffff;
            bridge.completeBridgeToken(user,sourceChain_,nonce_,amount_);   
        }

        else if (success_ == 2) {
            uint256 nonce_ = (value_ >> 128) & 0xffffffffffffffff;
            uint256 amount_ = value_ & 0xffffffffffffffffffffffffffffffff;
            bridge.cancelBridgeToken(user,sourceChain_,nonce_,amount_);   
        }
        
        else{
            bool success = bridge.remoteMintReceiver(payload_);
            if (success) {
            gateway.callContract(
                sourceChain_,
                sourceAddress_,
                payload_ = abi.encode(user,uint256(1 << 224)) // crosschain report success
                );
            }
            else {       
                gateway.callContract(
                sourceChain_,
                sourceAddress_,
                payload_ = abi.encode(user,uint256(2 << 224)) // crosschain report failed
                );
            }
          
        }
       

    }



}