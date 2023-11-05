// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract Ticket {



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
    ]



    


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
    
      



 




}