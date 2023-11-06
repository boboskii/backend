// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "solmate/auth/Owned.sol";

contract Lottery is IERC20, Ownable {
    IERC20 public token;

    // Event
    event BoughtTicket(address indexed from, uint256 amount, uint40[] bets);
    event claimed(address indexed from, uint256 indexed round,uint256 messageCode);//messageCode 0 succeeded ,1 no prize,2 reserveinsufficient
    event Jackpot(address indexed from, uint256 indexed round,uint256 quantity);
    event JackpotClaimed(address indexed from, uint256 indexed round,uint256 indexed quantity,string message);
    // Errors
    error PaymentFailed(address from,uint256 ErrorCode);
    error WaitSevenDays(address from,uint256 ErrorCode);
    error ZeroAddress(address from,uint256 ErrorCode);
    error NotCollector(address from,uint256 ErrorCode);
    error NotExecutor(address from,uint256 ErrorCode);
    error NotEnoughfeess(uint256 fees);
    error NotStandardTicket(address from, uint40[]);

        // constant
    // 常量设置
    uint16[14] public constant betMulti=[1,1,1,1,1,6,21,56,126,252,462,792,1287,2002]; //彩票价格除数
    uint16[5][9] public constant winMulti=[
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

    uint8 public status = 0; // 参数，
    uint8 public PriceDivChange ;

    // accounting Variables 资金相关变量
    uint32[3][] public historyPD=[[100,0,0xffffffff]]; //彩票价格除数历史[除数，起始轮次，结束轮次]
    uint32 public priceDiv=100; // 当前价格除数，价格为1/priceDiv
    uint32 public requestedPriceDiv;
    uint128 public ticketSum = 0; // 当期销售额，
    uint128 public highPool = 0; // 当前头奖资金池
    uint128 public lowPool = 0; // 当前低等级奖资金池
    uint128 public reserve = 0; // 储备金库
    uint128 public rollPool = 0;
    uint128 public fees = 0; // 费用库
    uint128 public currentRound = 0; // 彩票轮次

    address public collector;//fees 收集者
    address public executor;//自动执行人
    uint128[7] public lowPoolTemp = [0,0,0,0,0,0,0]; // 
    uint128[7] public highPoolTemp = [0,0,0,0,0,0,0]; // 

    mapping(uint256 => uint256) LPpaymentPool; // 2,3等奖永久池 round->amount
    mapping(uint256 => uint256) HPpaymentPool; // 1等奖永久池 round->amount
    mapping(uint256 => uint256) CouponOwnerBonus; // NFT id->amount
    mapping(uint256 => address) CouponOwneraddress; // NFT id->amount 
  
    
    uint16[] public winNumber; //彩票中奖号
    uint32[] public jackpotSum; //头奖总计票数
 
    uint32[2][] public roundPeriod=[0,0xffffffff]; //彩票轮次时间段，[起始时间，结束时间]
    mapping(address => mapping(uint256 => uint80[] )) ticketsRecord; // 用户彩票记录 address=>round =>ticketCode array
    mapping(uint256 => address[]) jackpotWinner; // round->address winner record
    mapping(address => mapping(uint256 => uint128[2])) prizeAmount; // address->round winner record[low,high]
 


    // 构造函数设置不同网络的AirnodeRrp合约地址，参数_airnodeRrpAddress
    constructor() {}

    /*//////////////////////////////////////////////////////////////  
                            For DAO
    //////////////////////////////////////////////////////////////*/
    modifier onlyExecutor() {
         if(msg.sender != executor){
            revert();
        }
         _;
    }

    modifier onlyCollector() {
         if(msg.sender != collector){
            revert();
        }
         _;
    }

    function Withdrawfees() external onlyCollector returns(bool) {
        if(fees>10){
            token.transfer(executor,fees);
            fees=0;
            return true;
        }else {
            revert(NotEnoughfeess());
            return false;
        }
    }

    function setPriceDivRequest(uint32 _newPriceDiv) external onlyOwner {
        PriceDivChange = 1;
        requestedPriceDiv = _newPriceDiv;

    }

    function setCollector(address _newCollector) external onlyOwner {
        if(_newCollector == address(0)){
            revert();
        }
       collector=_newCollector;
    }

    function setExecutor(address _newExecutor) external onlyOwner {
        if(_newExecutor == address(0)){
            revert();
        }
        executor=_newExecutor;
    }

    /*//////////////////////////////////////////////////////////////  
                            For Lottery logic
    //////////////////////////////////////////////////////////////*/

    function startNewRound() external onlyExecutor {

        if(PriceDivChange == 1){
            historyPD[historyPD.length-1][2]=currentRound;//设置调整前价格除数数组
            historyPD.push([requestedPriceDiv,currentRound+1,0xffffffff]);//设置调整后价格除数数组
            priceDiv=requestedPriceDiv; //设置当前价格除数
        }
        //清算当前轮
        //0.获取随机函数
        //winNumber[currentRound]=random();
        //if (!success ){random2()} //如果失败，再来一次,或后备随机数
        //if (!success ){revert}
        //1.清算低等奖金
        uint256 l = lowPoolTemp[(currentRound+7)%7];//取出之前temp数据，    
        lowPoolTemp[(currentRound+7)%7]=lowPool;//设置temp为当前轮数据，temp可以取钱，和fp不同。
        lowPool = l + rollPool/2; //设置当前轮数据，当前轮数据=之前temp数据+当前轮数据


        //2.清算头奖
        //a. 当前轮大于6，7轮前有人中奖，7轮钱的fp暂存计入永久池。
        if (jackpotSum[currentRound-7]>0 ){
            if (currentRound>6 ){
                HPpaymentPool[currentRound-7]=highPoolTemp[currentRound % 7]; //设置永久池数据，round-7轮，round 0-6时，暂存池为0值不变
            }       
            highPoolTemp[(currentRound+7)%7]=highPool; //暂存池已空，填入当前值数据，0轮即可，但需要+7，否则出错
            highPool=rollPool/2;
        }
       //b. 当前轮大于6，7轮前无人中奖，永久池计入0。
        if (jackpotSum[currentRound-7]=0 ){
            uint256 t = highPoolTemp[currentRound % 7];//取出暂存池数据，
          if (currentRound>6 ){
               HPpaymentPool[currentRound-7]=0;// 设置永久池数据，round-7轮，第7轮开始才需要设置
            }
            highPoolTemp[(currentRound+7)%7]=highPool; //暂存池已空，填入当前值数据，0轮即可，但需要+7，否则出错
            highPool=t+rollPool/2;//暂存池已空，填入缓存数据
        }
           
        //3. 设置上一轮结束时间，当前轮开始时间，当前轮次加1
        roundPeriod[currentRound-1][1]=[block.timestamp];
        roundPeriod.push([block.timestamp,0xffffffff]);
        ++currentRound;
    }



    function winnerClaim(uint256 _round) external  {
        uint16 t;//ticket code
        uint256 q;//ticket quantity
        uint256 w;//Jackpot quantity
        uint256 m;//mulitbet number
        uint256 amount_=0;
        uint80[] memory c = ticketsRecord[msg.sender][_round];//ticket number record

        if (c[0] & uint80(1<<1 | 1) == 2){
            revert(msg.sender,"already claimed");
        }
        else if (c[0] & uint80(0x11) == 1){
            lowPrizeClaim(c, _round) ;
        }
        else{

        for(uint i = 0; i < c.length; ++i) {
            t = uint16(c[i]>>64);
            m = uint256((c[i]>>4) & 0xf);
            q = uint256(c[i]>>40 & 0xffffff);
             
            if (m=0 ){
                if (t == winNumber[_round]){
                    c[i] = c[i] | uint80(0x1101) ; //1101头奖claimed，状态更改
                    w += q; //头奖总计票数   
                } 

                else {
                    t = t & winNumber[_round];
                    if (checkOneBits(t)==4){
                    c[i] = c[i] | uint80(0x1001);//1001二奖claimed，状态更改
                    amount_ += q*20/priceDiv;
                    }
                    if (checkOneBits(t)==3){
                    c[i] = c[i] | uint80(0x0101);//0101三奖claimed，状态更改
                    amount_ += q*2/priceDiv;
                    }
             
                }
               
            }//单式计算结束

            if (m>0 ){
                    t = t & winNumber[_round];
                    uint256 count=checkOneBits(t);
                    if (count==5){
                        c[i] = c[i] | uint80(0x1101) ; //1101头奖claimed
                        w += uint256(t & uint40(0xffffff)); //头奖总计票数 
                        amount_ += q*20*winMulti[m-6][0]/priceDiv; //同时获得的二奖
                        amount_ += q*2*winMulti[m-6][1]/priceDiv; //同时获得的三奖
                    }

                    if (checkOneBits(t)==4){
                        c[i] = c[i] | uint80(0x1001) ; //1001二奖claimed，状态更改
                        amount_ += q*20*winMulti[m-6][2]/priceDiv; //同时获得的二奖
                        amount_ += q*2*winMulti[m-6][3]/priceDiv; //同时获得的三奖
                    }

                    if (checkOneBits(t)==3){         
                        c[i] = c[i] | uint80(0x0101);//0101三奖claimed，状态更改
                        amount_ += q*2*winMulti[m-6][4]/priceDiv; //同时获得的三奖
                    }    
                        
            }//复式计算结束

        }
        }//for循环结束，最终支付阶段
        if (amount_ > 0 ){
            prizeAmount[msg.sender][_round][0] = amount_;
            }
        Settlement(c,w,amount_,_round);
    }

    function Settlement(uint80[] memory c,uint256 w,uint256 amount_,uint256 _round) internal {

        ticketsRecord[msg.sender][_round] = c;
        if (w > 0 ){
            jackpotSum[_round] += w; //头奖总计票数
            jackpotWinner[_round].push(msg.sender);//头奖计入中奖者地址
            prizeAmount[msg.sender][_round][1] = w; //个人头奖总计票数
            emit Jackpot(msg.sender,_round,w); //发出事件
        }
        
        if (amount_ == 0 ){
            fullfilled(c, _round);
        emit claimed(msg.sender,_round,1);//messageCode 0 succeeded ,1 no prize,
        }

        if (amount_ > 0 ){
            if (lowPoolTemp[(currentRound+7)%7]>amount_){
                token.transfer(msg.sender,amount_);
                lowPoolTemp[(currentRound+7)%7] -= amount_;
                fullfilled(c, _round);
                ticketsRecord[msg.sender][_round] = c ;
                emit claimed(msg.sender,_round,0);//messageCode 0 succeeded
                }
            else if (reserve >amount_ ){
                token.transfer(msg.sender,amount_);
                reserve -= amount_;
                fullfilled(c, _round);
                ticketsRecord[msg.sender][_round] = c ;
                emit claimed(msg.sender,_round,0);//messageCode 0 succeeded
                }
            emit claimed(msg.sender,_round,2);//messageCode 0 succeeded ,1 no prize,2 reserveinsufficient
        }
        
    }

    function fullfilled(uint80[] memory c, uint256 _round) internal {
        for (uint256 i = 0; i < c.length; ++i) {
            c[i] = c[i] | uint80(0x10) ; //状态更改为paid
        }
        ticketsRecord[msg.sender][_round] = c;
    }

    function lowPrizeClaim(uint80[] memory c,uint256 _round) internal {
        uint256 amount_=prizeAmount[msg.sender][_round][0];
            if (lowPoolTemp[(currentRound+7)%7]>amount_){
                token.transfer(msg.sender,amount_);
                lowPoolTemp[(currentRound+7)%7] -= amount_;
                fullfilled(c, _round);    
                emit claimed(msg.sender,_round,0);//messageCode 0 succeeded
                }
            else if (reserve >amount_ ){
                token.transfer(msg.sender,amount_);
                reserve -= amount_;
                fullfilled(c, _round);
                emit claimed(msg.sender,_round,0);//messageCode 0 succeeded
                }
            emit claimed(msg.sender,_round,2);//messageCode 0 succeeded ,1 no prize,2 reserveinsufficient
      
    }



    function jackpotClaim(uint256 _round) external  {
        if (_round-8<0){
            revert(msg.sender,"please wait 7 days for otherplayer claim");
        }
        address[] memory c = jackpotWinner[_round];
        for (uint256 i = 0; i < c.length; i++) {
            if (c[i]==msg.sender){
                uint256 amount_=HPpaymentPool[_round]*(JPwinnerTicketSum[msg.sender][_round]/(jackpotSum[_round])/priceDiv);
                HPpaymentPool[_round]-=amount_;
                token.transfer(msg.sender,amount_);
                emit JackpotClaimed(msg.sender, _round,amount_,"u win");//messageCode 0 succeeded
            }
        }

    }

    function buyTickets(uint40[] calldata _bets, uint256 calldata _coupon) external {
        uint256 amount_ = 0;//total purchase amount
        uint80 memory t;//signed ticket code uint80
        uint256 c;//count of win number
        uint256 q;//quantity in ticket
        uint256 m;//mulitbet number
        uint256 all;// sum of all ticket
           for (uint256 i = 0; i < _bets.length; i++) {
             //coupon 发行号1001-1999
                if (q=0 | q>10000000){
                    revert(NotStandardTicket(msg.sender, _bets));
                }
                if (_coupon>1000 & _coupon<2000) {
                    q = _bets[i] & uint40(0xffffff);
                    t = uint80((_bets[i]<<32 | uint72(block.timestamp)<<8)); //运算优先级，还需要检查
                    c = checkOneBits(_bets[i]);
                    t = t | uint80(c<<2);//构造票据储存格式
                    ticketsRecord[msg.sender][currentRound].push(t);
                    all += betMulti[c]*q/priceDiv;            
                    lowPool += all * 42 / 100;
                    highPool += all * 36 / 100;
                    rollPool += all / 10;
                    fees += all * 4 / 100;
                    reserve += all * 2 / 100;
                    CouponOwnerBonus[_coupon] += amount_ * 3 / 100;
                    //以上为收入，以下为支出
                    amount_ += all * 97 / 100;
                } 
                if(_coupon<1001 | _coupon>1999) {
                    q = _bets[i] & uint40(0xffffff);
                    t = uint80((_bets[i]<<32 | uint72(block.timestamp)<<8)); //运算优先级，还需要检查
                    c = checkOneBits(_bets[i]);
                    t = t | uint80(c<<2);//构造票据储存格式
                    ticketsRecord[msg.sender][currentRound].push(t);
                    all += betMulti[c]*q/priceDiv;            
                    lowPool += all * 43 / 100;
                    highPool += all * 38 / 100;
                    rollPool += all / 10;
                    fees += all * 7 / 100;
                    reserve += all * 2 / 100;
                    //以上为收入，以下为支出
                    amount_ += all;
                }

            } // for循环结束

        if (token.transferFrom(msg.sender, address(this), amount_)) {
            emit BoughtTicket(msg.sender, amount_,_bets);
        } else {
            revert PaymentFailed(msg.sender, 101);
        }

    }

   

  function claimBonus(uint256 calldata claimRound_) external {

      mapping(uint256 => uint256) CouponOwnerBonus; // NFT id->amount
    mapping(uint256 => address) CouponOwneraddress; // NFT id->amount 

    }
   

    /*//////////////////////////////////////////////////////////////  
                            Free Function
    //////////////////////////////////////////////////////////////*/

    function checkPriceDiv(uint128 _round) public view returns(uint256){
        uint256 i=0;
        while (historyPD[i][2]<_round){
            ++i;
        }
        return historyPD[i][0];
    }
    
    function checkOneBits(uint16  _ticketNumber) public pure returns(uint256){
        uint256 count_=0;
        do {
            _ticketNumber &= _ticketNumber-1;
            ++count_;
        } 
        while (_ticketNumber !=0);
        return count_;
    }

    function ticketCodeToArray(uint16 _ticketNumber) public pure returns(uint256[5] memory){
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
    
    // 不必要的函数
    function ArrayToTicketCode(uint256[5] memory _winNumberArray) public pure returns(uint16){
        uint16 winNumberPackcode_;
        for(uint i = 0; i < 5; ++i) {
            winNumberPackcode_ |= (1 << _winNumberArray[i]);
        }
        return winNumberPackcode_;
    }

    /*//////////////////////////////////////////////////////////////  
                            Public Query
    //////////////////////////////////////////////////////////////*/

    function queryBought(uint128 _round) external view returns (uint256) {
        return ticketsRecord[msg.sender][_round];
    }

    function queryJackpotWinner(uint128 _round) external view returns (uint256) {
        return jackpotWinner[_round];
    }




}
