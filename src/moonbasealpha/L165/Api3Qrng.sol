//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";

contract Api3Qrng is RrpRequesterV0 {
    // Qrng event
    // 参考：https://github.com/api3dao/qrng-example/blob/main/contracts/QrngExample.sol
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);

    // 参考：https://docs.api3.org/reference/qrng/providers.html
    // moobeam https://docs.moonbeam.network/cn/builders/integrations/oracles/api3/

    address public constant airnode = 0x6238772544f029ecaBfDED4300f13A3c4FE84E1D; //moonbeam alpha address
    bytes32 public constant endpointIdUint256Array = 0x27cc2713e7f968e4e86ed274a051a5c8aaee9cca66946f23af6f29ecea9704c3; // Nodary Endpoint ID (uint256[])  moonbeam alpha 返回数组，已修改
    address payable public sponsorWallet;

    mapping(bytes32 => bool) public waitingFulfillment;

    // These are for Remix demonstration purposes, their use is not practical.
    struct LatestRequest {
        bytes32 requestId;
        uint256[5] randomNumber;
    }

    LatestRequest public latestRequest;

    // Normally, this function should be protected, as in:
    // require(msg.sender == owner, "Sender not owner");
    constructor(address _airnodeRrpAddress) RrpRequesterV0(_airnodeRrpAddress) {}

    function SetsponsorWallet(address sponsor_) external {
        sponsorWallet = payable(sponsor_);
    }

    function makeRequestUint256Array(uint256 size) external {
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
        waitingFulfillment[requestId] = true;
        emit RequestedUint256Array(requestId, size);
    }

    function fulfillUint256Array(bytes32 requestId, bytes calldata data) external onlyAirnodeRrp {
        require(waitingFulfillment[requestId], "Request ID not known");
        waitingFulfillment[requestId] = false;
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));
        // Do what you want with `qrngUint256Array` here...
        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }
}
