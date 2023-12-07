// SPDX-License-Identifier: MIT

pragma solidity 0.8.22;

import {Ownable} from "solady@0.0.145/src/auth/Ownable.sol";

interface Itoken {
    function bridgeMint(address _user, uint256 _amount) external returns (bool);

    function bridgeBurn(address _user, uint256 _amount) external returns (bool);
}

interface IBridgeRouter {
    function remoteMint(
        string calldata _destinationChain,
        string calldata _destinationAddress,
        bytes calldata _payload
    ) external;
}

contract bridge is Ownable {
    error NotBridgeRouter();
    uint256 private immutable currentChainId;
    Itoken private token;
    IBridgeRouter private bridgeRouter;
    uint256 private ordinal;
    mapping(string => uint256) private chainIdMap; //chainID => ordinal => bool(0 false, 1 true)
    mapping(uint256 => mapping(uint256 => uint256)) private mintState; //chainID => ordinal => state(0 false, 1 true)
    mapping(uint256 => uint256) private burnState; //ordinal => state(0 null, 1 pending , 2 suceed , 3 mintback)

    event TokenBridged(
        address indexed user,
        uint256 indexed chainId,
        uint256 indexed ordinal,
        uint256 amount
    );

    event TokenBridgeCaneled(
        address indexed user,
        uint256 indexed chainId,
        uint256 indexed ordinal,
        uint256 amount
    );

    constructor(address _newOwner) {
        _initializeOwner(_newOwner);
        currentChainId = block.chainid;
    }

    function setTokenAddress(address _token) external onlyOwner {
        token = Itoken(_token);
    }

    function getTokenAddress() public view returns (address) {
        return address(token);
    }

    function setBridgeRouter(address _bridgeRouter) external onlyOwner {
        bridgeRouter = IBridgeRouter(_bridgeRouter);
    }

    function getBridgeRouter() public view returns (address) {
        return address(bridgeRouter);
    }

    function setChainIdMap(
        string calldata _chainName,
        uint256 _chainId
    ) external {
        chainIdMap[_chainName] = _chainId;
    }

    function getChainId(
        string calldata _chainName
    ) public view returns (uint256) {
        return chainIdMap[_chainName];
    }

    function brigeToken(
        string calldata _destinationChain,
        string calldata _destinationAddress,
        uint256 _amount //整数,未乘1e18
    ) external {
        token.bridgeBurn(msg.sender, _amount * 1e18);
        ordinal++;
        uint256 data = (uint256(uint160(msg.sender)) << 96) |
            (_amount << 64) |
            (ordinal << 32);
        burnState[ordinal] = data | (getChainId(_destinationChain) << 8) | 1;
        bytes memory _payload = abi.encode(data | (currentChainId << 8) | 1);
        bridgeRouter.remoteMint(
            _destinationChain,
            _destinationAddress,
            _payload
        );
    }

    function remoteMintReceiver(
        bytes calldata _payload
    ) external onlyBridgeRouter returns (bool) {
        uint256 data_ = abi.decode(_payload, (uint256));
        uint256 chainId_ = (data_ >> 8) & 0xffffff;
        uint256 ordinal_ = (data_ >> 32) & 0xffffffff;
        address user_ = address(uint160(data_ >> 96));
        uint256 amount_ = (data_ >> 64) & 0xffffffff;
        require(mintState[chainId_][ordinal_] == 0, "already minted");
        bool success = token.bridgeMint(user_, amount_);
        if (success) {
            mintState[chainId_][ordinal_] = data_;
        }
        return success;
    }

    function completeBridgeToken(
        bytes calldata _payload
    ) external onlyBridgeRouter {
        uint256 data_ = abi.decode(_payload, (uint256));
        address user_ = address(uint160(data_ >> 96));
        uint256 amount_ = (data_ >> 64) & 0xffffffff;
        uint256 ordinal_ = (data_ >> 32) & 0xffffffff;
        uint256 chainid_ = (data_ >> 8) & 0xffffff;
        burnState[ordinal_] = data_;
        emit TokenBridged(user_, chainid_, ordinal_, amount_);
    }

    function cancelBridgeToken(
        bytes calldata _payload
    ) external onlyBridgeRouter {
        uint256 data_ = abi.decode(_payload, (uint256));
        address user_ = address(uint160(data_ >> 96));
        uint256 amount_ = (data_ >> 64) & 0xffffffff;
        uint256 ordinal_ = (data_ >> 32) & 0xffffffff;
        uint256 chainid_ = (data_ >> 8) & 0xffffff;
        bool success = token.bridgeMint(msg.sender, amount_ * 1e18);
        if (success) burnState[ordinal_] = data_;
        emit TokenBridgeCaneled(user_, chainid_, ordinal_, amount_);
    }

    modifier onlyBridgeRouter() {
        if (msg.sender != address(bridgeRouter)) {
            revert NotBridgeRouter();
        }
        _;
    }
}
