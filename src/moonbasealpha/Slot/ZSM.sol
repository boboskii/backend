// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "solmate/mixins/ERC4626.sol";
import "solmate/auth/Owned.sol";

contract ZSM is ERC4626, Owned {

    mapping(address => uint256) public shareHolder;//4626,shareHolder

    uint128 public fees ; // 费用库
    address public collector;

    uint256 public contractBalance;
    uint256 round = 0;
    uint8[3] speed0 = [31, 51, 71];
    uint8 acceleration = 10;

    event Result(address indexed from, uint256 timestamp, string message);
    event result(uint256[], uint256[], uint256);
    event balances(uint256 betAmount, uint256 userBalance, uint256 contractBalance);

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {

    }

    modifier onlyCollector() {
        if (msg.sender != collector) {
            revert();
        }
        _;
    }


    function withDrawFees() external onlyCollector returns (bool) {
        if (fees > 10) {
            asset.transfer(collector, fees);
            fees = 0;
            return true;
        } else {
            revert(NotEnoughfeess());
            return false;
        }
    }

// 4626
    function _deposit(uint _assets) public {
    // checks that the deposited amount is greater than zero.
    require(_assets > 0, "Deposit less than Zero");
    // calling the deposit function ERC-4626 library to perform all the functionality
    deposit(_assets, msg.sender);
    // Increase the share of the user
    shareHolder[msg.sender] += _assets;
}

   // 4626 returns total number of assets
    function totalAssets() public view override returns (uint256) {
    return asset.balanceOf(address(this));
    } 

    // returns total balance of user ???
    function totalAssetsOfUser(address _user) public view returns (uint256) {
    return asset.balanceOf(_user);
    }

    function totalShareOfUser(address _user) public view returns (uint256) {
    return asset.balanceOf(_user);
    }

    /**
    * @notice Function to allow msg.sender to withdraw their deposit plus accrued interest
    * @param _shares amount of shares the user wants to convert
    * @param _receiver address of the user who will receive the assets
    */
    function _withdraw(uint _shares, address _receiver) public {
    // checks that the deposited amount is greater than zero.
    require(_shares > 0, "withdraw must be greater than Zero");
    // Checks that the _receiver address is not zero.
    require(_receiver != address(0), "Zero Address");
    // checks that the caller is a shareholder
    require(shareHolder[msg.sender] > 0, "Not a shareHolder");
    // checks that the caller has more shares than they are trying to withdraw.
    require(shareHolder[msg.sender] >= _shares, "Not enough shares");
    // Calculate 10% yield on the withdraw amount
    uint256 percent = (2 * _shares) / 1000;
    // Calculate the total asset amount as the sum of the share amount plus 10% of the share amount.
    uint256 assets = _shares + percent;
    // calling the redeem function from the ERC-4626 library to perform all the necessary functionality
    redeem(assets, _receiver, msg.sender);
    // Decrease the share of the user
    shareHolder[msg.sender] -= _shares;

    }



    function play(uint256 _betAmount) public payable {
        // Uncomment below code once dummy user has balance
    }

    function logicOfLuck(uint256 _betAmount) public payable {
        uint8 reel1 = random();
        uint8 reel2 = random();
        uint8 reel3 = random();
        emit Nums(reel1, reel2, reel3);
        bool isWin = false;
        uint256 prizeAmount = 0 wei;

        if (reel1 == reel2 || reel2 == reel3 || reel3 == reel1) {
            // Check if all same
            if (reel1 == reel2 && reel2 == reel3) {
                prizeAmount = _betAmount * 3 wei;
                console.log(prizeAmount);
                emit Result(msg.sender, block.timestamp, "JACKPOT! You tripled your ETH bet");
            } else {
                emit Result(msg.sender, block.timestamp, "Congratulations. You doubled your ETH bet");
                prizeAmount = _betAmount * 2 wei;
                console.log(prizeAmount);
            }
            isWin = true;
        } else {
            emit Result(msg.sender, block.timestamp, "Loser. :)");
        }

        if (isWin) {
            require(prizeAmount <= address(this).balance, "Trying to withdraw more money than the contract has.");
            (bool success,) = (msg.sender).call{value: prizeAmount}("");
            require(success, "Failed to withdraw money from contract.");
        }
    }

    //单次下注
    function betOnce() public returns (uint256) {}

    //多次下注
    function betMulti() public returns (uint256) {}

    //随机函数
    function randomT() public returns (uint256) {
        uint256 t = uint256(keccak256(abi.encodePacked(block.timestamp))) % 20;
        round++;
        return t;
    }

    //慢雾安全团队建议开发者们不要将用户的下注与开奖放在同一个交易内
    //防止攻击者通过检测智能合约中的开奖状态实现交易回滚攻击。
    function random() public returns (uint256[] memory, uint256[] memory, uint256) {
        uint256 bonusRate = 0;
        uint256[] memory slot = new uint[](3);
        uint256[] memory step = new uint[](3);
        uint256 t = randomT();

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
