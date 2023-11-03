// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is IERC20, Ownable {
    IERC20 public token;

    event BoughtTicket(address indexed from, uint16[9][] bets);
    // Errors
    // 错误，彩票合约专属事件。

    error PaymentFailed(uint256 ErrorCode);

    //
    mapping(uint256 => address) CouponOwner;

    // Global Variables
    // 全局变量

    uint256 public pot = 0; // total amount of ether in the pot，奖池中的总金额，会计参数
    uint256 public reserve = 0; // reserve fund for bonus payment，支付的储备基金，会计函数
    uint256[] public bonus = [0]; // 当前轮可领取的奖金，初始值bonus[0]=0,在构造函数设定，会计函数
    uint256 public fee = 0; // 手续费总额，会计函数
    //彩票参数
    uint256 public ticketPrice = 0; //彩票价格，the price of a ticket，会计参数
    uint256 public startTime; // datetime that current round lottery is starting，当前轮开始的日期时间
    uint256 public round = 0; // 彩票轮次

    //可遍历的,用户参数
    mapping(uint256 => address[]) players; // 参与轮次=>下注者地址
    mapping(address => mapping(uint256 => uint16[9][])) buyRecord; // 某一轮的购买数组，[号码，注数][nonce]

    mapping(uint256 => uint256) public firstPrizeBetAmount; // 头奖注数，mapping to store each round first prize winners amounts
    mapping(uint256 => uint16[5]) winNumber; //mapping to store each rounds winning number，开盘结果，轮次=>号码
    mapping(uint256 => uint256) CouponBonus; //mapping to store each rounds betAmmount，开盘结果，轮次=>总金额，统计函数,不储存,前端调用时计算
    mapping(uint256 => address) CouponOwner; //mapping to store each rounds betAmmount，开盘结果，轮次=>总金额，统计函数,不储存,前端调用时计算

    // 构造函数设置不同网络的AirnodeRrp合约地址，参数_airnodeRrpAddress
    constructor() {}

    function startNewRound() external onlyOwner {
        uint256 _baseFund = (reserve + pot);
        reserve = _baseFund * 2 / 100; // 2% of the pot is reserved for bonus payment if bonus is not enough.
        bonus.push(_baseFund * 80 / 100) = _baseFund * 80 / 100; // 80% of the pot is bonus
        pot = _baseFund * 18 / 100; // 20% of the pot is reserved for the next round
        round = round + 1;
        startTime = block.timestamp;
    }

    // calldate struct: [0，1，2，3，4，5:tickets,6:coupon,7:id,8:isclaimed][]

    function buyTickets(uint16[9][] calldata bets_, uint256 calldata coupon_, bool calldata usecoupon_) external {
        uint256 _amount = 0;
        uint256 i;
        for (i = 0; i < bets_.length; i++) {
            if (
                bets_.length < 11 && bets_[i][5] > 0 && bets_[i][0] < bets_[i][1] && bets_[i][1] < bets_[i][2]
                    && bets_[i][2] < bets_[i][3] && bets_[i][3] < bets_[i][4]
            ) {
                //coupon 发行号1001-1999
                if (usecoupon_) {
                    _amount = (bets_[i][5] + _amount) * ticketPrice * 97 / 100;
                    buyRecord[msg.sender][round].push(bets_[i]);
                    pot += _amount * 90 / 97;
                    fee += _amount * 4 / 97;
                    CouponBonus[bets_[i][6]] += _amount * 3 / 97;
                } else {
                    _amount += bets_[i][5] * ticketPrice;
                    buyRecord[msg.sender][round].push(bets_[i]);
                    pot += _amount * 93 / 100;
                    fee += _amount * 7 / 100;
                }
            } // if条件语句结束
            else {
                revert BetdataNotStandard(2);
            }
        } // for循环结束
        if (token.transferFrom(msg.sender, address(this), _amount)) {
            emit BoughtTicket(msg.sender, buyRecord[msg.sender][round]);
            players[round].push(msg.sender);
        } else {
            revert PaymentFailed(2);
        }
    }

    //  mapping(uint256 => address[]) players; // 参与轮次=>下注者地址
    //  mapping(address => mapping(uint256 => uint[6][])) buyRecord; // 某一轮的购买数组，[5号码，6注数][nonce]
    // calldate struct: [uint256 _round,uint256 _nonce][uint256 _times]
    function claimBonus(uint256 calldata claimRound_) external {
        address _player = msg.sender;
        uint256 memory _amount = 0;
        uint256[][] memory _betdata = buyRecord[_player][claimRound_];
        for (uint256 i = 0; i < _betdata.length; i++) {
            iswin();
        }

        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "transfer failed");
    }

    // mapping(uint256 => address[]) players; // 参与轮次=>下注者地址
    // 遍历一期的所有购买地址，计算头奖总注数，

    function firstPrizeBetAmountCheck(uint256 calldata round_) public view returns (uint256) {
        uint8[5] memory _code;
        address[] _players = players[round]; // 本期下注者地址
        uint256 memory _amount = 0; // 本期头奖总注数
        uint256[5][] memory _betdata = buyRecord[_players][round_]; //每个下注者的购买数据

        for (uint256 i = 0; i < _players.length; i++) {
            for (uint256 j = 0; j < _betdata[1][i]; j++) {
                _code = [_betdata[0][j], _betdata[1][j], _betdata[2][j], _betdata[3][j], _betdata[4][j]];
                if (_code == winNumber[round]) {
                    firstPrizeBetAmount[round] += _betdata[5][j]; //[5][i]是注数
                }
            }
            return firstPrizeBetAmount[round];
        }
    }
}
