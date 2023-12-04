// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import {Ownable} from "@solady/auth/Ownable.sol";

interface Itoken {
    function allowance(address owner,address spender) external view returns (uint256);

    function bridgeMint(address to_, uint256 amount_) external returns (bool);

    function bridgeBurn(address from_, uint256 amount_) external returns (bool);
}

interface IBridgeRouter {

    function remoteMint(
        string calldata destinationChain_,
        string calldata destinationAddress_,
        uint256  value_
    ) external;

}

contract bridge is Ownable {

    error NotBridgeRouter();
    uint256 private immutable chainId ;
    Itoken private token;
    IBridgeRouter private bridgeRouter;
    uint256 private nonce;
    mapping (string =>uint256 ) private  chainIdMap; //chainID => nonce => bool(0 false, 1 true)
    mapping(uint256 => mapping(uint256 => uint256 )) private IsMinted; //chainID => nonce => bool(0 false, 1 true)
    mapping(uint256 => uint256 ) private IsBurned; //chainID => nonce => bool(0 false, 1 true)
    
    event TokenBridged(
        address indexed user,
        string indexed chain,
        uint256 indexed nonce,
        uint256 amount
    );

    constructor(address newOwner_,uint256 chainId_) {
        _initializeOwner(newOwner_);
        chainId = chainId_;
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

    function setChainIdMap(
        string calldata chainName_,
        uint256 chainId_
    ) external {
        chainIdMap[chainName_]=chainId_;
    }

    function getChainId(
        string calldata chainName_
    ) public returns (uint256) {
        return chainIdMap[chainName_];
    }

    function brigeToken(
        string calldata destinationChain_,
        string calldata destinationAddress_,
        uint256 amount_
    ) external {
        require (token.allowance(msg.sender, address(this)) >= amount_, 'allowance not enough');
        token.bridgeBurn(msg.sender, amount_);
        nonce++;
        IsBurned[nonce] = 1;
        uint256 data = amount_ | nonce << 128 | chainId << 192 ;
        address user = msg.sender;
        bytes payload_ = abi.encode(user,data);
        bridgeRouter.remoteMint(destinationChain_, destinationAddress_,payload_);
    }

    function remoteMintReceiver(
        bytes calldata payload_
    ) external onlyBridgeRouter()  returns (bool) {
        address user;
        uint256 value_;
        (user,value_)= abi.decode(payload_, (address,uint256));   
        uint256 chainId_ = (value_ >> 192) & 0xffffffff;
        uint256 nonce_ = (value_ >> 128) & 0xffffffffffffffff;
        uint256 amount_ = value_ & 0xffffffffffffffffffffffffffffffff;
        require (IsMinted[chainId_][nonce_] == 0, 'already minted');
        bool success = token.bridgeMint(user, amount_);
        if (success) {
            IsMinted[chainId_][nonce_] = 1;
        }
        return success;
    }

    function completeBridgeToken(
        address user,
        string calldata chain_ ,
        uint256 nonce_ ,
        uint256 amount_
    ) external onlyBridgeRouter() {
        emit TokenBridged( user, chain_ , nonce_, amount_ );
    }

    function cancelBridgeToken(
        address user,
        string calldata chain_ ,
        uint256 nonce_ ,
        uint256 amount_
    ) external onlyBridgeRouter()  {
        token.bridgeMint(user, amount_);
        IsBurned[nonce_] = 2;
        emit TokenBridgeCaneled( user, chain_ , nonce_, amount_ );
    }

    modifier onlyBridgeRouter() {
        if (msg.sender != bridgeRouter) {
            revert(NotBridgeRouter());
        }
        _;
    }

}
