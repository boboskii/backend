// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "solmate@6.2.0/src/mixins/ERC4626.sol";
import "@api3/airnode-protocol@0.13.0/contracts/rrp/requesters/RrpRequesterV0.sol";

contract ZSM is ERC4626,RrpRequesterV0 {



    //slot viarables

    uint256 playNonces;
    mapping(uint256 => uint256) public playRecode;

    // api3
    address public airnode ;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    uint16[16] public qrngU16Array;
    address public sponsorWallet;
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;


    event Result(address indexed from,uint8[3][] indexed result, uint256 bonus);

    event RequestedArray(bytes32 indexed requestId, uint256 size);
    event ReceivedArray(bytes32 indexed requestId, uint16[16] response);


    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _airnodeRrp
    ) ERC4626(_asset, _name, _symbol) RrpRequesterV0(_airnodeRrp) {
        _asset = ERC20(0x0);
        _name = "Zeno Slot Machine Shares-MB-VDOT";
        _symbol = "ZS-MB-VDOT";
    }

        /*//////////////////////////////////////////////////////////////
                            VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    // 4626 returns total number of assets
    function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
    } 

    /**
    * @notice Function to allow msg.sender to withdraw their deposit plus accrued interest
    * @param _assets amount of assets the user wants to deposit
    */
    function _deposit(uint _assets) public {
    require(_assets > 0, "Require greater than Zero");
    // calling the deposit function ERC-4626 library to perform all the functionality
    deposit(_assets, msg.sender);
    // Increase the share of the user
    }

    /**
    * @notice Function to allow msg.sender to withdraw their deposit plus accrued interest
    * @param _shares amount of shares the user wants to convert
    */
    function _withdraw(uint _shares) public {
    require(_shares > 0, "Require greater than 0");
    require(balanceOf[msg.sender] > 0, "Not a shareHolder");
    require(balanceOf[msg.sender] >= _shares, "Not enough shares");
    redeem(_shares, msg.sender, msg.sender);
    }


    /*//////////////////////////////////////////////////////////////
                          API3  RANDOM LOGIC
    //////////////////////////////////////////////////////////////*/

    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    function makeRandomArray(uint256 size) internal   {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfill.selector,
            // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedArray(requestId, size);
    }

    function fulfill(bytes32 requestId, bytes calldata data)
        external
        onlyAirnodeRrp
    {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));     
        play()
        emit ReceivedArray(requestId, qrngU16Array);
    }



    /*//////////////////////////////////////////////////////////////
                            SLOTMACHINE LOGIC
    //////////////////////////////////////////////////////////////*/

    
    function insertionSort(uint256[] memory a) public pure returns(uint256[] memory) {
        // note that uint can not take negative value
        for (uint i = 1;i < a.length;i++){
            uint temp = a[i];
            uint j=i;
            while( (j >= 1) && (temp < a[j-1])){
                a[j] = a[j-1];
                j--;
            }
            a[j] = temp;
        }
        return(a);
    }

    function play(uint256 _betAmount) public payable {
 
    }

     //单次下注
    function bet(uint256 _betAmount,uint256 times) public returns (bool) {
        require(_betAmount > 0 ,'Must greater than zero');
        require(_betAmount < totalAssets()/4 ,'Must lower than a quarter of totalAssets');
        require(times>0 && times<6,'Only can play 1-5 times')
        ++playNonces;
        playRecode[playNonces] = uint160(msg.sender) << 96 | uint88(_betAmount) << 8 | uint8(times);
        makeRandomArray(3*times);
        return ture;
    }

    //多次下注
    function betMulti() public returns (uint256) {}

 
    function Bets(uint256 _betAmount,uint256 _rounds) public returns (uint256[] memory, uint256[] memory, uint256) {
        uint256 bonusRate = 0;
        uint256[] memory slot = new uint[](3);
        uint256[] memory step = new uint[](3);
        uint256 t = randomT();
        random(3);

        for (uint256 i = 0; i < 3; i++) {
            step[i] =
                speed0[i] * t + (acceleration * t ** 2) / 2 + (speed0[i] + acceleration * t) ** 2 / (2 * acceleration);
            slot[i] = (
                (speed0[i] * t + (acceleration * t ** 2) / 2 + (speed0[i] + acceleration * t) ** 2 / (2 * acceleration))
                    % 7
            ) + 1;
        }

        emit result(slot, step, t);

        if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 1) {
            bonusRate = 100;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 2) {
            bonusRate = 25;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 3) {
            bonusRate = 20;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 4) {
            bonusRate = 15;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 5) {
            bonusRate = 10;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 6) {
            bonusRate = 5;
        } else if (slot[0] == slot[1] && slot[1] == slot[2] && slot[0] == 7) {
            bonusRate = 3;
        } else if (slot[0] == slot[1] && slot[1] != slot[2]) {
            bonusRate = 2;
        } else if (slot[0] != slot[1] && slot[1] == slot[2]) {
            bonusRate = 2;
        } else {
            bonusRate = 0;
        }
        return (slot, step, bonusRate);
    }

    //安全检查1：溢出攻击
    //安全检查2：重入攻击
    //安全检查3：交易顺序依赖攻击
    //安全检查4：随机数攻击
    //安全检查5：回退攻击
    //安全检查6：矿工攻击
    //安全检查7：时间依赖攻击
    //安全检查8：预言机操纵攻击
    //安全检查9：权限漏洞
    //安全检查10：合约升级漏洞
    //安全检查11：合约授权漏洞
    //安全检查12：函数逻辑漏洞
}
