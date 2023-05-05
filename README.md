# damn-vulnerable-defi-3.0.0-writeup
Challenge #1 - Unstoppable<br>
-
攻击目标：完成对UnstoppableVault合约中闪电贷功能的DDOS攻击<br>
初始条件：10个 DVT token<br>
合约分析：在UnstoppableVault合约的闪电贷功能对应的函数中，共有4个if语句完成了相关的条件判断，<br>
```solidity
        if (amount == 0) revert InvalidAmount(0); // fail early
        if (address(asset) != _token) revert UnsupportedCurrency(); // enforce ERC3156 requirement
        if (receiver.onFlashLoan(msg.sender, address(asset), amount, fee, data) != keccak256("IERC3156FlashBorrower.onFlashLoan"))
            revert CallbackFailed();
```
以上三条件if语句分别完成闪电贷金额、金库地址以及IERC3156中onFlashLoan函数返回值的检查，正常闪电贷逻辑以及写在ReceiverUnstoppable合约中的onFlashLoan函数都不会触发回滚条件<br>
```solidity
        if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); // enforce ERC4626 requirement
```
剩下的这条if语句中，变量balanceBefore被赋值为taotalAssets()函数的返回值，taotalAssets()函数的实现如下<br>
```solidity
    function totalAssets() public view override returns (uint256) {
        assembly { // better safe than sorry
            if eq(sload(0), 2) {
                mstore(0x00, 0xed3ba6a6)
                revert(0x1c, 0x04)
            }
        }
        return asset.balanceOf(address(this));
    }
```
直接返回了闪电贷对应代币地址中的余额,如果能采用非mint的方式改变代币地址中的余额，条件判断将失效，使得交易失败并回滚。可以利用账户中初始的10个代币,直接向代币合约转账完成攻击。<br>

Challenge #2 - Naive receiver
-
攻击目标:在单个交易中拿走闪电贷用户合约中所有的ETH<br>
初始条件：用户合约中有10个ETH<br>
合约分析：NaiveReceiverLenderPool合约中的闪电贷函数没有对闪电贷的金额进行检查，因此可以进行闪电贷金额为0的贷款操作。同时每次闪电贷的收费固定为1ETH，只需要调用用户的FlashLoanReceiver合约
完成十次闪电贷，FlashLoanReceiver合约中的金额将全部被用来支付闪电贷费用。<br>

Challenge #3 - Truster
-
攻击目标:在单个交易中拿走pool中的所有token<br>
初始条件：pool中token数量：1 million <br>
合约分析：TrusterLenderPool合约闪电贷函数中存在对call方法的调用，调用过程中msg.sender为合约本身，可利用call方法完成token对攻击账户的approve，在闪电贷完成后进行转账清空pool。<br>

Challenge #4 - Side Entrance
-
攻击目标:拿走pool中的所有ETH<br>
初始条件：1ETH balance <br>
合约分析：在SideEntranceLenderPool合约中，deposit函数采用的ETH记账，闪电贷的借款也是采用ETH，如果在闪电贷中借出ETH，并在execute函数中全部deposit，此时还款条件满足，攻击者也被记入了deposit名单，
可以合法进行withdraw，拿走pool中所有的ETH。<br>

Challenge #5 - The Rewarder
-
攻击目标: 获得deposit奖励 <br>
初始条件：no token <br>
合约分析：deposit奖励的分发功能在TheRewarderPool合约中的distributeRewards()函数中实现<br>
```solidity
    function distributeRewards() public returns (uint256 rewards) {
        if (isNewRewardsRound()) {
            _recordSnapshot();
        }
        

        uint256 totalDeposits = accountingToken.totalSupplyAt(lastSnapshotIdForRewards);
        uint256 amountDeposited = accountingToken.balanceOfAt(msg.sender, lastSnapshotIdForRewards);

        if (amountDeposited > 0 && totalDeposits > 0) {
            rewards = amountDeposited.mulDiv(REWARDS, totalDeposits);
            if (rewards > 0 && !_hasRetrievedReward(msg.sender)) {
                rewardToken.mint(msg.sender, rewards);
                lastRewardTimestamps[msg.sender] = uint64(block.timestamp);
            }
        }
    }
````
函数首先判断当前的时间戳是否满足newRound，即距离上次快照时间是否过去了5天，如果是则进行新一轮快照。而后续rewardToken的分配中，是按照新一轮快照的结果进行分配的。也就是说，如果攻击账户利用闪电贷进行deposit，
则新一轮的奖励分配就会按照闪电贷deposit的数量进行份额配，那么攻击者将获得与deposit数量相对应的rewardToken，在获得奖励再归还闪电贷借款，即可完成攻击。<br>

Challenge #6 - Selfie
-
攻击目标:拿走pool中的1.5m token<br>
初始条件：no token<br>
合约分析：治理合约SimpleGovernance中queueAction()函数里对于提案资格的判定可以通过闪电贷借款绕过(只需要当前攻击合约的余额数量大于快照时代币总数量的一半即可)，在闪电贷借款后完成快照操作，将emergencyExit()函数
写入提案队列，然后还款并执行提案即可完成攻击。<br>

Challenge #7 - Compromised
-
攻击目标:获取交易所中所有的ETH token<br>
初始条件：0.1 ETH <br>
合约分析：对题干中出现的16进制编码进行转换，可以得到两个私钥分别为0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9，0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48。
预言机合约TrustfulOracle初始化时有三个公钥地址，猜测其中有两个公钥对应到解析出的两个私钥。同时观察到预言机合约中对于NFT定价的函数_computeMedianPrice中采用了取中位数的方法给NFT定价，因此只要有两个账户的权限即可
完成对NTF价格的修改。利用已破解的两个私钥账户修改价格进行购买，再修改价格进行卖出，可以得到交易所中所有的ETH，最后将NFT价格改回至初始价格，完成攻击。

Challenge #8 - Puppet
-
攻击目标:获取交易所中所有的token <br>
初始条件：25ETH 1000DVT <br>
合约分析：PuppetPool合约中价格计算函数_computeOraclePrice()实现为：
```solidity
    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
````
可以看到当unisawpPair合约中ETH数量越少，DVT数量越多时，DVT价格越低，借出所有DVT所需要deposit的ETH就越少。<br>
使用账户中所有的DVT去unisawpPair合约里换取ETH，此时DVT的价格被压到当前情况下的最低，借出所有DVT需要的ETH不到20，可以完成攻击。

Challenge #9 - Puppet V2
-
攻击目标:获取交易所中所有的token <br>
初始条件：20WETH 1000DVT <br>
合约分析：和challege#8 类似的方式，只是使用WETH以及UniswapV2接口来完成操作。在对应的代币交换池中使用WETH交换DVT，压低DVT价格，然后用所有的WETH来借出池子里所有的DVT，完成攻击，实现过程中注意ERC20代币与ETH操作时候
的一些不同以及uniswapV2与uniswapV1的接口差异。<br>

Challenge #10 - Free Rider
-
攻击目标:获取所有NFT以及交易所的ETH <br>
初始条件：0.1ETH <br>
合约分析：在FreeRiderNFTMarketplace交易所合约中，函数buyone()的购买逻辑出现了问题。
```solidity
    function _buyOne(uint256 tokenId) private {
        uint256 priceToPay = offers[tokenId];
        if (priceToPay == 0)
            revert TokenNotOffered(tokenId);

        if (msg.value < priceToPay)
            revert InsufficientPayment();
        
        --offersCount;

        // transfer from seller to buyer
        DamnValuableNFT _token = token; // cache for gas savings
        _token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);
        

        // pay seller using cached token
        payable(_token.ownerOf(tokenId)).sendValue(priceToPay);
        //买了以后钱又回来了 因为先transfer了，所以owner变了。

        emit NFTBought(msg.sender, tokenId, priceToPay);
    }
````
在完成NFT的购买以后，交易所应该将NFT转移给买方，将支付的ETH转给卖方，但是在购买逻辑中，在完成NFT所有权转移以后，_token.ownerOf(tokenId)此时变为了NFT的买方，通过payable(_token.ownerOf(tokenId)).sendValue(priceToPay)，又把购买NFT的费用转移给了买方，因此买方可以免费获得NFT。由于初始资金有限，只能通过uniswapV2提供的flashswap来进行闪电贷完成攻击。

Challenge #11 - Backdoor
-
攻击目标:拿走registry合约中的所有DVT token <br>
初始条件：无 <br>
合约分析：需要熟悉Gnosis钱包的创建流程，用户通过GnosisSafeProxyFactory合约中的createProxyWithCallback函数创建代理合约，在代理合约创建完后会调用WalletRegistry合约中的proxyCreated函数，通过系列检查后将给对应的钱包派发DVT奖励。
在使用createProxyWithCallback函数进行代理合约的创建时，会在代理合约中使用call方法调用initializer完成代理合约的初始化，随后调用callback地址上的proxyCreated函数进行初始化检查并完成相关操作，如果能在initializer中完成钱包对攻击地址的DVT授权，便可以在钱包完成初始化，通过callback函数检查后将奖励的DVT token转移到攻击者账户，完成攻击。





         
