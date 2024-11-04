// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "abdk-libraries-solidity/ABDKMath64x64.sol";

library ApyCalculation {

    function twelveQuad(int128 x) internal pure returns (int128) {
        return ABDKMath64x64.pow(x,ABDKMath64x64.toUInt(ABDKMath64x64.div(ABDKMath64x64.fromInt(1), ABDKMath64x64.fromInt(12))));
    }
   function calculateDailyApy(uint _annualApy) public pure returns (uint256) {
        uint256 annualApy = _annualApy*1e16;  
        return (annualApy/36500);
    }

    function calculatePartialReward(uint lastTimestamp,uint _APY,uint amount) internal view returns (uint) {
        uint256 timeDifference =  block.timestamp>lastTimestamp? (block.timestamp-lastTimestamp):0;
        uint256 daysDifference = timeDifference / 86400;
        uint dailyApy=calculateDailyApy(_APY);
        return dailyApy*daysDifference*amount/1e18;
    }
    function getTheFee(uint locktimestamp,uint amount) internal view returns (uint) {
       require(locktimestamp != 0, "Timestamp must be valid");
        uint256 timeDifference =  locktimestamp>block.timestamp?locktimestamp-block.timestamp:0;
        uint256 daysDifference = timeDifference / 86400;
        uint256  DECIMAL_PRECISION = 100000;
        uint256  PERCENTAGE = 3125; 
        return (daysDifference>32?32:daysDifference)*PERCENTAGE*amount/DECIMAL_PRECISION;
    }
}
