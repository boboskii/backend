// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;


contract bridgeCode {

    uint256 public ordinal=666;
    bytes public payload;
    uint256 public data;
    address public user;
    uint256 public amount;
    uint256 public chainid;
    uint256 public state;
    mapping (string =>uint256 ) private  chainIdMap; //chainID => ordinal => bool(0 false, 1 true)
    mapping(uint256 => mapping(uint256 => uint256 )) private mintState; //chainID => ordinal => bool(0 false, 1 true)
    mapping(uint256 => uint256 ) private burnState; //chainID => ordinal => bool(0 false, 1 true)

    constructor() {

    }

    function payloaDcode(
        uint256 _amount
    ) external {
        ordinal++;

        data = uint256(uint160(msg.sender)) << 96 | _amount << 64| ordinal<<32 ;
        burnState[ordinal] = data | 999 << 8 | 1;
        payload = abi.encode(data | block.chainid << 8 | 1);

    }

    function payloadDecode(
    ) external  {
        (data)= abi.decode(payload, (uint256));
        user = address(uint160(data >> 96));
        amount = (data >> 64) & 0xffffffff;
        ordinal = (data >> 32) & 0xffffffff;
        chainid = (data >> 8) & 0xffffff;
        state = data  & 0xff;
    }
