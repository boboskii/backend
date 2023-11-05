// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is IERC20, Ownable {
    IERC20 public token;


    // Event
    event BoughtTicket(address indexed from, uint16[] bets);
    event claimed(address indexed from, uint256 indexed round,uint256 messageCode);//messageCode 0 succeeded ,1 no prize,2 reserveinsufficient
    event winFP(address indexed from, uint256 indexed round,uint256 quantity);
    event FPclaimed(address indexed from, uint256 indexed round,uint256 indexed quantity,string message);
    // Errors
    error PaymentFailed(uint256 ErrorCode);
    error wait7days(address from,string message);



    //NFT module
    mapping(uint256 => address) CouponOwner;

        // constant
    // 常量设置
    uint16[14] public constant multiBetTicketsFactor=[1,1,1,1,1,6,21,56,126,252,462,792,1287,2002]; //彩票价格除数
    uint16[5][9] public constant multiBetWinFactor=[
            [5,0,2,4,3],
            [10,10,3,12,6],
            [15,30,4,24,10],
            [20,60,5,40,15],
            [25,100,6,60,21],
            [30,150,7,84,28],
            [35,210,8,112,36],
            [40,280,9,144,45],
            [45,360,10,180,55]
    ]; //复投中奖数预计算

    // accounting Variables 资金相关变量
    uint32[3][] public historyDivisor=[[100,0,0xffffffff]]; //彩票价格除数历史[除数，起始轮次，结束轮次]
    uint32 public Divisor=100; // 当前价格除数，价格为1/priceDec
    uint256 public salesAmount = 0; // 当期销售额，
    uint256 public currentFPpool = 0; // 当前头奖资金池
    uint256 public currentLPpool = 0; // 当前低等级奖资金池
    uint256 public reserve = 0; // 储备金库
    uint256 public fee = 0; // 费用库
    address public colletor;//fee 收集者

    uint256 public LPpoolTemp = [0,0,0]; // 头奖暂存池,256bit is nessesary,index->amount
    uint256 public FPpoolTemp = [0,0,0,0,0,0,0]; // 头奖暂存池,256bit is nessesary,index->amount

    mapping(uint256 => uint256) LPpool; // 2,3等奖永久池 round->amount
    mapping(uint256 => uint256) FPpool; // 1等奖永久池 round->amount
    mapping(uint256 => uint256) CouponOwnerBonus; // NFT id->amount
    mapping(uint256 => address) CouponOwneraddress; // NFT id->amount 
  
    uint256 public currentRound = 0; // 彩票轮次
    uint16[] public winNumber; //彩票中奖号
    uint32[] public FPquantitySum; //头奖总计票数
    uint8 public status = 0; // 参数，
    uint32[2][] public roundPeriod=[0,0xffffffff]; //彩票轮次时间段，[起始时间，结束时间]
    mapping(address => mapping(uint256 => uint80[] )) ticketsRecord; // 用户彩票记录 address=>round =>ticketCode array
    mapping(uint256 => address[]) FPwinner; // round->address winner record
    mapping(address => mapping(uint256 => uint256)) FPquantityPlayer; // address->round winner record


    // 构造函数设置不同网络的AirnodeRrp合约地址，参数_airnodeRrpAddress
    constructor() {}

    /*//////////////////////////////////////////////////////////////  
                            For DAO
    //////////////////////////////////////////////////////////////*/

  
    function setPriceDivisor(uint32 _newPriceDivisor) external onlyOwner {
        PriceDivisor[PriceDivisor.length-1][2]=round+1;//设置调整前价格除数数组
        PriceDivisor.push([_newPriceDivisor,round,0xffffffff]);//设置调整后价格除数数组
        Divisor=_newPriceDivisor; //设置当前价格除数
    }

    function setColletor(address _newColletor) external onlyOwner {
        colletor=_newColletor;
    }

     function depositFPpool(uint256 _round) external onlyOwner{
        token.transferFrom(msg.sender,amount_);
        FPpool[_round] += (amount_*priceDec);
    }
 
    /*//////////////////////////////////////////////////////////////  
                            For Lottery logic
    //////////////////////////////////////////////////////////////*/

    function startNewRound() external onlyOwner {
        //清算当前轮
        //0.获取随机函数
        //winNumber[currentRound]=random();
        //if (!success ){random2()} //如果失败，再来一次,或后备随机数
        //if (!success ){revert}
        //1.清算低等奖金
        uint256 l = LPpoolTemp[(currentRound+3)%3];//取出之前temp数据，    
        LPpoolTemp[(currentRound+3)%3]=currentLPpool;//设置temp为当前轮数据，temp可以取钱，和fp不同。
        currentLPpool=l*5/10;
        reserve += l*5/10;

        //2.清算头奖
        //a. 当前轮大于6，7轮前有人中奖，7轮钱的fp暂存计入永久池。
        if (FPquantitySum[currentRound-7]>0 ){
            if (currentRound>6 ){
                FPpool[currentRound-7]=FPpoolTemp[currentRound % 7]; //设置永久池数据，round-7轮，round 0-6时，暂存池为0值不变
            }       
            FPpoolTemp[(currentRound+7)%7]=currentFPpool; //暂存池已空，填入当前值数据，0轮即可，但需要+7，否则出错
            currentFPpool=0;
        }
       //b. 当前轮大于6，7轮前无人中奖，永久池计入0。
        if (FPquantitySum[currentRound-7]=0 ){
            uint256 t = FPpoolTemp[currentRound % 7];//取出暂存池数据，
          if (currentRound>6 ){
               FPpool[currentRound-7]=0;// 设置永久池数据，round-7轮，第7轮开始才需要设置
            }
            FPpoolTemp[(currentRound+7)%7]=currentFPpool; //暂存池已空，填入当前值数据，0轮即可，但需要+7，否则出错
            currentFPpool=t;//暂存池已空，填入缓存数据
        }
           
        //3. 设置上一轮结束时间，当前轮开始时间，当前轮次加1
        roundPeriod[currentRound-1][1]=[block.timestamp];
        roundPeriod.push([block.timestamp,0xffffffff]);
        ++currentRound;
    }



    function winnerClaim(uint256 _round) external  {
        uint16 t;//ticket code
        uint256 q;//ticket quantity
        uint256 w;//winFP quantity
        uint256 m;//mulitbet number
        uint256 amount_=0;
        uint80[] memory c = ticketsRecord[msg.sender][_round];//ticket number record

        for(uint i = 0; i < c.length; ++i) {
            t = uint16(c[i]>>64);
            m = uint256((c[i]>>4) & 0xf);
            q = uint256(c[i]>>40 & 0xffffff);
             
            if (m=0 ){
                if (t == winNumbers[_round]){
                    c[i] = c[i] | uint80(0x1101) ; //1101头奖claimed，状态更改
                    w += q; //头奖总计票数   
                } 

                else {
                    t = t & winNumbers[_round];
                    if (checkOneAmount(t)==4){
                    c[i] = c[i] | uint80(0x1001);//1001二奖claimed，状态更改
                    amount_ += q*20/priceDec;
                    }
                    if (checkOneAmount(t)==3){
                    c[i] = c[i] | uint80(0x0101);//0101三奖claimed，状态更改
                    amount_ += q*2/priceDec;
                    }
             
                }
               
            }//单式计算结束

            if (m>0 ){
                    t = t & winNumbers[_round];
                    uint256 count=checkOneAmount(t);
                    if (count==5){
                        c[i] = c[i] | uint80(0x1101) ; //1101头奖claimed
                        w += uint256(t & uint40(0xffffff)); //头奖总计票数 
                        amount_ += q*20*multiBetWinFactor[m-6][0]/priceDec; //同时获得的二奖
                        amount_ += q*2*multiBetWinFactor[m-6][1]/priceDec; //同时获得的三奖
                    }

                    if (checkOneAmount(t)==4){
                        c[i] = c[i] | uint80(0x1001) ; //1001二奖claimed，状态更改
                        amount_ += q*20*multiBetWinFactor[m-6][2]/priceDec; //同时获得的二奖
                        amount_ += q*2*multiBetWinFactor[m-6][3]/priceDec; //同时获得的三奖
                    }

                    if (checkOneAmount(t)==3){         
                        c[i] = c[i] | uint80(0x0101);//0101三奖claimed，状态更改
                        amount_ += q*2*multiBetWinFactor[m-6][4]/priceDec; //同时获得的三奖
                    }    
                        
            }//复式计算结束

        }//for循环结束，最终支付阶段

        ticketsRecord[msg.sender][_round] = c;
        if (w > 0 ){
            FPquantitySum[_round] += w; //头奖总计票数
            FPwinner[_round].push(msg.sender);//头奖计入中奖者地址
            FPquantityPlayer[msg.sender][_round] = w; //个人头奖总计票数
            emit winFP(msg.sender,round,w); //发出事件
        }
        
        if (amount_ == 0 ){
        emit claimed(msg.sender,round,1);//messageCode 0 succeeded ,1 no prize,
        }
        else {
            if (LPpoolTemp[(currentRound+3)%3]>amount_){
                token.transfer(msg.sender,amount_);
                LPpoolTemp[(currentRound+3)%3] -= amount_;
                emit claimed(msg.sender,round,0);//messageCode 0 succeeded
                }
            else if (reserve >amount_ ){
                token.transfer(msg.sender,amount_);
                reserve -= amount_;
                emit claimed(msg.sender,round,0);//messageCode 0 succeeded
                }
            emit claimed(msg.sender,round,2);//messageCode 0 succeeded ,1 no prize,2 reserveinsufficient
          }

    }

    function FPclaim(uint256 _round) external  {
        if (_round-8<0){
            revert(msg.sender,"please wait 7 days for otherplayer claim");
        }
        address c = FPwinner[_round];
        for (uint256 i = 0; i < FPwinner[_round].length; i++) {
            if (a[i]==msg.sender){
                uint256 amount_=FPpool[_round]*(FPquantityPlayer[msg.sender][_round]/(FPquantitySum[_round])/priceDec);
                FPpool[_round]-=amount_;
                token.transfer(msg.sender,amount_);
                emit FPclaimed(msg.sender, _round,amount_,"u win");//messageCode 0 succeeded
            }
        }

    }

    function buyTickets(uint40[] calldata bets_, uint256 calldata coupon_) external {
        uint256 _amount = 0;
        uint256 i;
        uint80 memory t;
        uint256 c;
        uint256 q;
           for (i = 0; i < bets_.length; i++) {
             //coupon 发行号1001-1999
                if (coupon_>0) {
                    q = bets_[i] & uint40(0xffffff);
                    t = uint80((bets_[i]<<32 | uint72(block.timestamp)<<8)); //运算优先级，还需要检查
                    c = checkOneAmount(bets_[i]);
                    t = t | uint80(c<<2);//构造票据储存格式
                    ticketsRecord[msg.sender][currentRound].push(t);
                    _amount = (q/Divisor) * (97 / 100);
                    currentLPpool +=
                    currentFPpool +=
                    fee += _amount * 4 / 97;
                    reserve += 
                    CouponOwnerBonus[coupon_] += _amount * 3 / 97;
                } else {
                    q = bets_[i] & uint40(0xffffff);
                    t = uint80((bets_[i]<<32 | uint72(block.timestamp)<<8)); //运算优先级，还需要检查
                    c = checkOneAmount(bets_[i]);
                    t = t | uint80(c<<2);//构造票据储存格式
                    ticketsRecord[msg.sender][currentRound].push(t);
                    _amount = (q/Divisor) * (97 / 100);
                    currentLPpool +=
                    currentFPpool +=
                    fee += _amount * 4 / 97;
                    reserve += ;
                }
           

            } // for循环结束

        if (token.transferFrom(msg.sender, address(this), _amount)) {
            emit BoughtTicket(msg.sender, buyRecord[msg.sender][round]);
        } else {
            revert PaymentFailed(2);
        }
    }

  function claimBonus(uint256 calldata claimRound_) external {

      mapping(uint256 => uint256) CouponOwnerBonus; // NFT id->amount
    mapping(uint256 => address) CouponOwneraddress; // NFT id->amount 

    }
   

    /*//////////////////////////////////////////////////////////////  
                            Free Function
    //////////////////////////////////////////////////////////////*/
    
    function winNumberCompare(uint16 ticket,uint256 _round) external returns(uint) {
    uint n;
    n = ticket & winNumber(_round);
    return n=checkOneAmount(uint16(n));
    }

    function checkOneAmount(uint16  _ticketNumber) public pure returns(uint256){
        uint256 count_=0;
        do {
            _ticketNumber &= _ticketNumber-1;
            ++count_;
        } 
        while (_ticketNumber !=0);
        return count_;
    }

    function winNumberPackedcodeToArray(uint16 _ticketNumber) public pure returns(uint256[5] memory){
        uint256[5] memory winNumberArray_;
        uint256 j=0;
        for(uint i = 0; i < 16; ++i) {
            if (_ticketNumber & (1 << i ) != 0){
                winNumberArray_[j] = 16-i;
                ++j;
            }
 
        }
        return winNumberArray_;
    }

    function winNumberArrayToPackedcode(uint256[5] memory _winNumberArray) public pure returns(uint16){
        uint16 winNumberPackcode_;
        for(uint i = 0; i < 5; ++i) {
            winNumberPackcode_ |= (1 << _winNumberArray[i]);
        }
        return winNumberPackcode_;
    }











    




    //  mapping(uint256 => address[]) players; // 参与轮次=>下注者地址
    //  mapping(address => mapping(uint256 => uint[6][])) buyRecord; // 某一轮的购买数组，[5号码，6注数][nonce]
    // calldate struct: [uint256 _round,uint256 _nonce][uint256 _times]
  

    // mapping(uint256 => address[]) players; // 参与轮次=>下注者地址
    // 遍历一期的所有购买地址，计算头奖总注数，

    function firstPrizeBetAmountCheck(uint256 calldata round_) public view returns (uint256) {
        uint8[5] memory _code;

    }

 

    function ticketVerify(uint40[] memory _ticketArray) public  returns (bool)  {
          
        for (uint i = 0; i < ticketArray.length; ++i) {
            if (ticketCode[i] == 0) {
                return false;
            }
            if (ticketCode[i] == 0) {
                return false;
            }

        } 
    }
    


   
    



}
