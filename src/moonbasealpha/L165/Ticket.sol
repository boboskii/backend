// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract Ticket {
    // Events
    
    event NoPrize(address indexed from, uint256 round);

    // Custom errors
    error InvalidRounds();
    error InvalidTicket(uint256 errorCode);

    // testing variables
    uint public c=0;
    uint16 public numbers=0;
    uint[5] public  win = [1,2,3,4,5];
   
    // constant
    // 常量设置
    uint16[14] public constant multiBetTicketsFactor=[1,1,1,1,1,6,21,56,126,252,462,792,1287,2002]; //彩票价格除数
    uint16[5][9] public constant multiBetWinFactor=[
            [5, 0, 2, 4, 3],
            [10, 10, 3, 12, 6],
            [15, 30, 4,	24,	10],
            [20, 60, 5,	40,	15],
            [25, 100, 6, 60, 21],
            [30, 150, 7, 84, 28],
            [35, 210, 8, 112, 36],
            [40, 280, 9, 144, 45],
            [45, 360, 10, 180, 55]
    ]; //复投中奖数预计算

    // 可设置模块，需要owner模块，未完成
    function setPriceDivisor(uint32 _newPriceDivisor) external onlyOwner {
        PriceDivisor[PriceDivisor.length-1][2]=round+1;//设置调整前价格除数数组
        PriceDivisor.push([_newPriceDivisor,round,0xffffffff]);//设置调整后价格除数数组
        currentPriceDivisor=_newPriceDivisor; //设置当前价格除数
    }

 


    uint32[3][] public PriceDivisor=[[100,0,0xffffffff]]; //彩票价格除数历史[除数，起始轮次，结束轮次]
    uint32 public currentPriceDivisor=100; // 当前价格除数，价格为1/priceDec
    uint32 public round = 0;        //轮次
    uint16[] public winNumbers=[0]; //中奖号码
    mapping(address => mapping(uint256 => uint80[] )) ticketsRecord; // address=>round =>ticketCode array
    mapping(uint256 => mapping(address => uint256 )) firstPriceRecord;//轮次 赢家 票数



    // library
    function checkWinNumberAmount(uint16  _ticketNumber) public pure returns(uint256){
        uint256 count_=0;
        do {
            _ticketNumber &= _ticketNumber-1;
            ++count_;
        } 
        while (_ticketNumber !=0);
        return count_;
    }
 
    
    //--j 发生下溢，不知解决方案，倒序问题前端再解决吧，
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


    function ticketBuyingCheck(uint40[] memory ticketArray) public  returns (bool)  {
          
        for (uint i = 0; i < ticketArray.length; ++i) {
            if (ticketCode[i] == 0) {
                return false;
            }
            if (ticketCode[i] == 0) {
                return false;
            }

        } 
    }

    function ticketClaimingCheck(uint256 _round) public  returns (bool)  {
          
        for (uint i = 0; i < ticketArray.length; ++i) {
            if (ticketCode[i] == 0) {
                return false;
            }
            if (ticketCode[i] == 0) {
                return false;
            }

        }
    }


    function ticketPublicCheck(uint256 _round) public  returns (bool)  {
          
        for (uint i = 0; i < ticketArray.length; ++i) {
            if (ticketCode[i] == 0) {
                return false;
            }
            if (ticketCode[i] == 0) {
                return false;
            }

        }
    }
    
      



 function winnerClaim(uint256 _choosedround) external  {
        uint16 ticketNumber;
        uint256 amount_=0;
        uint80[] memory copy = ticketsRecord[msg.sender][_choosedround];

        for(uint i = 0; i < copy.length; ++i) {
            ticketNumber=uint16(copy[i]>>64);

            if (ticketNumber == winNumbers[0]){
                copy[i] | uint80(1<<40) ;
                firstPriceRecord[_choosedround][msg.sender]=(copy[i]>>48)&0xffff;
                } 

            else {
                ticketNumber = ticketNumber & winNumbers[_choosedround];
                if (checkWinNumberAmount(ticketNumber)==4){
                   amount_ += ((copy[i]>>48) & 0xffff)*20/priceDec;
                }
                if (checkWinNumberAmount(ticketNumber)==3){
                   amount_ += ((copy[i]>>48) & 0xffff)*2/priceDec;
                }
         
              
            }
    
        }
        ticketsRecord[msg.sender][_choosedround]=copy;
        if (amount_ == 0){
        emit NoPrize(msg.sender,round);
        }
        else {
            //token.transfer(msg.sender,amount_);
        }
    }






    function random(uint d) public view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp,d)));
    }

    function generate() public  returns(uint[5] memory,uint16) {
        uint[5] memory n;
        uint t=0;
        for(uint i = 0; i < 5; ++i) {
            n[i] = uint16(random(i) % 16 + 1);
        }
        win = n;

        for  (uint j = 0; j < 5; ++j) {
             t= t | (1 << n[j]);
        }
        numbers = uint16(t);
        
       return (win,numbers);

    }

  

    function compare(uint16 ticket) external returns(uint) {
    uint n;
    n = ticket & numbers;
    return n=checkWinNumberAmount(uint16(n));
}

}
