// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "./AuthorizedExecutor.sol";
import "./SelfAuthorizedVault.sol";
import "hardhat/console.sol";
contract sweep {
    SelfAuthorizedVault vault;
    bytes4 selector;
    constructor(address _vault){
        vault = SelfAuthorizedVault(_vault);
    }
    function test() public returns (bytes4){
        selector = vault.sweepFunds.selector;
        return selector;
    }
}