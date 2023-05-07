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

合约分析：NaiveReceiverLenderPool合约中的闪电贷函数没有对闪电贷的金额进行检查，因此可以进行闪电贷金额为0的贷款操作。同时每次闪电贷的收费固定为1ETH，只需要调用用户的FlashLoanReceiver合约完成十次闪电贷，FlashLoanReceiver合约中的金额将全部
被用来支付闪电贷费用。<br>

Challenge #3 - Truster
-
攻击目标:在单个交易中拿走pool中的所有token<br>

初始条件：pool中token数量：1 million <br>

合约分析：TrusterLenderPool合约闪电贷函数中存在对call方法的调用，调用过程中msg.sender为合约本身，可利用call方法完成token对攻击账户的approve，在闪电贷完成后进行转账清空pool。<br>

Challenge #4 - Side Entrance
-
攻击目标:拿走pool中的所有ETH<br>

初始条件：1ETH balance <br>

合约分析：在SideEntranceLenderPool合约中，deposit函数采用的ETH记账，闪电贷的借款也是采用ETH，如果在闪电贷中借出ETH，并在execute函数中全部deposit，此时还款条件满足，攻击者也被记入了deposit名单，可以合法进行withdraw，拿走pool中所有的ETH。<br>

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

函数首先判断当前的时间戳是否满足newRound，即距离上次快照时间是否过去了5天，如果是则进行新一轮快照。而后续rewardToken的分配中，是按照新一轮快照的结果进行分配的。也就是说，如果攻击账户利用闪电贷进行deposit，则新一轮的奖励分配就会按照闪电贷deposit的数量进行份额配，那么攻击者将获得与deposit数量相对应的rewardToken，在获得奖励再归还闪电贷借款，即可完成攻击。<br>

Challenge #6 - Selfie
-
攻击目标:拿走pool中的1.5m token<br>

初始条件：no token<br>

合约分析：治理合约SimpleGovernance中queueAction()函数里对于提案资格的判定可以通过闪电贷借款绕过(只需要当前攻击合约的余额数量大于快照时代币总数量的一半即可)，在闪电贷借款后完成快照操作，将emergencyExit()函数写入提案队列，然后还款并执行提案即可完成攻击。<br>

Challenge #7 - Compromised
-
攻击目标:获取交易所中所有的ETH token<br>

初始条件：0.1 ETH <br>

合约分析：对题干中出现的16进制编码进行转换，可以得到两个私钥分别为0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9，0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48。

预言机合约TrustfulOracle初始化时有三个公钥地址，猜测其中有两个公钥对应到解析出的两个私钥。同时观察到预言机合约中对于NFT定价的函数_computeMedianPrice中采用了取中位数的方法给NFT定价，因此只要有两个账户的权限即可完成对NTF价格的修改。利用已破解的两个私钥账户修改价格进行购买，再修改价格进行卖出，可以得到交易所中所有的ETH，最后将NFT价格改回至初始价格，完成攻击。

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

合约分析：和challege#8 类似的方式，只是使用WETH以及UniswapV2接口来完成操作。在对应的代币交换池中使用WETH交换DVT，压低DVT价格，然后用所有的WETH来借出池子里所有的DVT，完成攻击，实现过程中注意ERC20代币与ETH操作时候的一些不同以及uniswapV2与uniswapV1的接口差异。<br>

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

在使用createProxyWithCallback函数进行代理合约的创建时，会在代理合约中使用call方法调用initializer完成代理合约的初始化，随后调用callback地址上的proxyCreated函数进行初始化检查并完成相关操作，如果能在initializer中完成钱包对攻击地址的DVT授权，便可以在钱包完成初始化，通过callback函数检查后将奖励的DVT token转移到攻击者账户，完成攻击。<br>

Challenge #12 - Climber
-
攻击目标:TODO<br>

初始条件：无 <br>

合约分析：TODO

Challenge #13 - Wallet Mining
-
攻击目标：1、拿走0x9b6fb606a9f5789444c17768c6dfcf2f83563801地址上的token。
         2、拿走所有代理合约中奖励的token。
         
初始条件: 无 <br>

合约分析：
1、攻击1为去年4000WOP代币事故的改版。要在未部署Gnosis工厂合约以及逻辑合约的链上获得未初始化地址中的token，首先需要重放交易，将工厂合约以及master逻辑合约部署在链上，重放交易需要交易不涉及chainID字段，且重放部署合约的费用也由最初链上的部署地址支付。因此，完成攻击目标1需要的步骤为：<br>

a) 获得Gnosis链上真实合约的部署代码（工厂合约以及master逻辑合约）以及部署合约的外部账户地址。<br>

b) 利用链上代码重放交易，完成合约部署。<br>

c) 使用Factory工厂合约中的createProxy函数，找到产生0x9b6fb606a9f5789444c17768c6dfcf2f83563801地址代理合约对应的nonce，在创建代理合约时候可以对合约进行初始化，在此过程中获得合约的一些权限完成攻击1。<br>

2、攻击2需要拿走代理合约中被奖励的token，具体来说，要产生0x9b6fb606a9f5789444c17768c6dfcf2f83563801特定地址代理合约需要不断地在工厂合约中新创建代理合约，因此在产生特定地址之前会不断地创建代理合约，这些代理合约会获得DVT奖励，攻击2的目标是把这些奖励也转移到攻击者账户。奖励发放的逻辑在WalletDeployer合约中的drop函数实现:<br>

 ```solidity
     function drop(bytes memory wat) external returns (address aim) {
        aim = fact.createProxy(copy, wat);
        if (mom != address(0) && !can(msg.sender, aim)) {
            revert Boom();
        }
        IERC20(gem).transfer(msg.sender, pay);
    }
```

具体来说，需要WalletDeployer合约中的can函数返回true才可以向msg.sender转出DVT。can函数是一段内联汇编函数，逐行解读一下can函数：

```solidity
        let m := sload(0) //读取WalletDeployer合约中第0个slot中的内容，const以及immutable类型都不会分配slot进行存储，因此此时m读到的为变量mom。
        if iszero(extcodesize(m)) {return(0, 0)}//判断mom对应的地址是否为合约，即是否存在代码，如果是非合约地址则return。
        let p := mload(0x40) //读取memory 0x40处32字节内容，即内存指针的值
        mstore(0x40,add(p,0x44)) //内存指针长度增加0x44，即分配0x44长度的内存空间
        mstore(p,shl(0xe0,0x4538c4eb)) // 将0x4538c4eb左移 0xe0位，存到指针位置
        mstore(add(p,0x04),u) //写入 u至memory，即drop函数中的msg.sender
        mstore(add(p,0x24),a) //写入 a至memory，即drop函数中的aim
        if iszero(staticcall(gas(),m,p,0x44,p,0x20)) {return(0,0)} //staticall mom地址，参数为0x4538c4eb + 地址u + 地址a，如果返回为1则通过检查，第五个参数p为函数返回值其实地址，第六个参数为返回值长度，即返回值为p处开始往后32字节长度
        if and(not(iszero(returndatasize())), iszero(mload(p))) {return(0,0)} // not(iszero(returndatasize()))，iszero(mload(p))，这两个布尔值不能同时为1
```
mom合约就是AuthorizerUpgradeable代理合约，0x4538c4eb是AuthorizerUpgradeable合约中can函数的函数选择器，即WalletDeployer合约调用了AuthorizerUpgradeable合约中的can函数来判断调用WalletDeployer合约的msg.sender是否符合要求，如果符合要求，便转账给WalletDeployer合约的调用者DVT。只有staticcall返回为1的时候，才能通过检查，而staticcall只要没有revert就默认调用成功返回success，即便函数不存在，也会返回success。所以如果staticcall调用成功，那么返回值不为0，而且返回值的size也不会0，所以最后的and语句为0，可以通过检查。<br>

如何使得staticcall能通过检查，如果能控制逻辑合约，使得逻辑合约自毁，当逻辑合约不存在时，staticcall将通过检查。<br>

查看测试脚本，可以发现

```javaScript
        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
```
在初始化阶段，仅仅只对代理合约进行了初始化，而逻辑合约是没有被初始化的，初始化函数中将函数调用者设定为了合约的owner。成为逻辑合约owner以后，可以调用upgradeToAndCall函数通过delegatecall的方式调用攻击合约来完成逻辑合约的自毁，此后再调用WalletDeployer合约中的drop函数能顺利通过staticcall，获得所有钱包的DVT。完成攻击2的步骤为：<br>

a) 拿到逻辑合约地址（UUPS代理模式下逻辑合约地址存储在固定的slot）初始化逻辑合约，获得owner权限。<br>

b) 利用owner权限调用upgradeToAndCall函数，通过攻击合约完成逻辑合页的自毁。<br>

c) 调用43次drop函数获取DVT，完成攻击2。<br>

Challenge #14 - Puppet V3
-
攻击目标: 拿走pool中所有token<br>

初始条件：1ETH 110DVT <br>

合约分析：同Puppet V1、Puppet V2，Puppet V3也是完成预言机的价格操作，与V1、V2不同的除了uniswap本身接口的改变，还有预言机机制的变化。V3中预言机价格的时间离散性更弱，安全性增强，具体表现为完成代币交换以后，价格需要一定时间才能回归到当前代币池中按照AMM进行瞬时计算的价格。因此如果要完成对应攻击，在调用对应接口完成代币交换后，需要等待一段时间，再进行PuppetV3Pool合约中borrow函数的调用完成攻击。<br>

Challenge #15 - ABI Smuggling
-
攻击目标: 将vault中的DVT转移到recovery账户<br>

初始条件：1ETH 110DVT <br>

合约分析：SelfAuthorizedVault合约中存在两个函数能够拿到DVT，withdraw函数单次可以拿回一个DVT，sweepFunds函数可以一次性拿走所有的DVT。在AuthorizedExecutor合约中，execute函数可以通过call方法进行函数调用<br>

```solidity
function execute(address target, bytes calldata actionData) external nonReentrant returns (bytes memory) {
        // Read the 4-bytes selector at the beginning of `actionData`
        bytes4 selector;
        uint256 calldataOffset = 4 + 32 * 3; // calldata position where `actionData` begins
        assembly {
            selector := calldataload(calldataOffset)
        }

        if (!permissions[getActionId(selector, msg.sender, target)]) {
            revert NotAllowed();
        }

        _beforeFunctionCall(target, actionData);

        return target.functionCall(actionData);
    }
```

分析execute函数，selector在actionData的固定位置读取，读取的selector需要通过permissions检查，在合约部署脚本中，和攻击账户有关的permissions设置为:<br>

```javaScript
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
```

只有如上形式的actionData才能通过检查，但是要使得call方法能够调用sweepFunds函数，还需要对actionData进行编码上的补充，构建actionData的方法如下：<br>

1）调用SelfAuthorizedVault合约中的execute函数，函数选择器为 0x1cff79cd，第一个参数为address类型的，设定为vault.address,第二个参数为bytes类型。bytes的编码为，第一个32字节存储bytes的起始位置，在起始位置处存放bytes的长度，而后再存储bytes本身的内容。考虑到selector的读取位置是0x64，可以将bytes的起始位置设置为64或者更长的位置（更长位置则中间补0）。<br>

2）在bytes起始位置设置bytes长度，根据sweepFunds函数，对应的bytes应该包括一个函数选择器+receiver地址+token地址，长度为 0x04+0x20+0x20 = 0x44。长度设置完成后设置对应bytes内容即可。<br>

3）构建actionData完成后使用EOA账户发送交易到SelfAuthorizedVault合约完成攻击。

         
