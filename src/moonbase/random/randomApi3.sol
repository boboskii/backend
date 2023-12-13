//SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@api3/airnode-protocol@0.13.0/contracts/rrp/requesters/RrpRequesterV0.sol";
import {Owned} from "solmate@6.2.0/src/auth/Owned.sol";

contract Api3Qrng is RrpRequesterV0,Owned {
    // Qrng event
    // 参考：https://github.com/api3dao/qrng-example/blob/main/contracts/QrngExample.sol
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedArray(bytes32 indexed requestId, uint256 size);
    event ReceivedArray(bytes32 indexed requestId, uint16[16] response);

    // 参考：https://docs.api3.org/reference/qrng/providers.html
    // https://docs.moonbeam.network/cn/builders/integrations/oracles/api3/
    // airnode ; 0x6238772544f029ecaBfDED4300f13A3c4FE84E1D
    // endpointIdUint256; 0x94555f83f1addda23fdaa7c74f27ce2b764ed5cc430c66f5ff1bcf39d583da36
    // endpointIdUint256Array; 0x9877ec98695c139310480b4323b9d474d48ec4595560348a2341218670f7fbc2
    

    // AirnodeRrpV0 Address https://docs.api3.org/reference/qrng/chains.html
    // AirnodeRrpV0 moonbase Address 0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd

    // 已部署 moonbase ：0x6466129Da686d7Dc98f21B45e987C2e67413aB25
    // sponsorWallet; 0xaa765704D7cdE2c2539117e68A2e47123f1c28C5

    address public airnode ;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    uint256 public qrngU256;
    uint16[16] public qrngU16Array;

    // https://docs.api3.org/reference/airnode/latest/packages/admin-cli.html#derive-sponsor-wallet-address
    address public sponsorWallet;

    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;



    constructor(
        address _airnodeRrp,
        address _owner
        ) RrpRequesterV0(_airnodeRrp) Owned(_owner) {
        
        }


    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) external onlyOwner() {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

     function makeRequestUint256() external returns (uint256) {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256(requestId);
        return qrngU256;
    }


    function fulfillUint256(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false; 
        qrngU256 = abi.decode(data, (uint256));
        emit ReceivedUint256(requestId, qrngU256);

    }


    function makeRequestArray(uint256 size) external returns (uint16[16] memory) {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedArray(requestId, size);
        return qrngU16Array;
    }

    function fulfillUint256Array(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));     
        for (uint256 i; i < qrngUint256Array.length; ++i) {
            qrngU16Array[i] = uint16(qrngUint256Array[i]);
        }
        emit ReceivedArray(requestId, qrngU16Array);
    }


}
