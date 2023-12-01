// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@solmate/mixins/ERC4626.sol";
import "solmate/auth/Owned.sol";

contract ZSM is ERC4626, Owned {

    //4626 accounting viarables
    uint256 public shareSum;
    uint256 public fees ; // 费用库
    address public collector;
    mapping(address=>uint256) shareHolder;

    //slot viarables
    uint64[3] randomNums;
    uint8 acceleration = 10;
    uint256 bonus;
    uint8[3][] result;

    event Result(address indexed from,uint8[3][] indexed result, uint256 bonus);
    error NotEnoughfeess();


    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC4626(_asset, _name, _symbol) Owned(_owner) {
        _asset = address(0x0);
        _name = "Zeno Slot Machine Shares-MB-VDOT";
        _symbol = "ZS-MB-VDOT";
        _owner = msg.sender;
    }


    /*//////////////////////////////////////////////////////////////
                            ZENO FEES LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier onlyCollector() {
        if (msg.sender != collector) {
            revert();
        }
        _;
    }

    function withDrawFees() external onlyCollector returns (bool, uint256) {
        if (fees > 10) {
            asset.transfer(collector, fees);
            return (true, fees);
            fees = 0;
        } else {
            revert(NotEnoughfeess());
            return (false, fees);
        }
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
    shareHolder[msg.sender] += _shares;
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
    shareHolder[msg.sender] -= _shares; // 写shareHolder，supply，balanceOf三个储存
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

    function random(uint256 number) public view returns(uint256[]) {
        for (uint256 i; i < number; ++i) {
            randomNums[i] = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty,i)));
        }
        return insertionSort(randomNums);
    }

    function play(uint256 _betAmount) public payable {
        // Uncomment below code once dummy user has balance
    }

     //单次下注
    function betOnce() public returns (uint256) {}

    //多次下注
    function betMulti() public returns (uint256) {}

 
    //慢雾安全团队建议开发者们不要将用户的下注与开奖放在同一个交易内
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
