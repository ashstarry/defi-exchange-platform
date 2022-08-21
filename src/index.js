import Web3 from "web3";
import EUSDArtifact from "../../build/contracts/EUSD.json";
import sTSLAArtifact from "../../build/contracts/sTSLA.json";
import sBNBArtifact from "../../build/contracts/sBNB.json";
import MintArtifact from "../../build/contracts/Mint.json";
import SwapArtifact from "../../build/contracts/Swap.json";
import BNBPFArtifact from "../../build/contracts/BNBPriceFeed.json";
import TSLAPFArtifact from "../../build/contracts/TSLAPriceFeed.json";

const App = {
    web3: null,
    account: null,
    meta: null,

    start: async function() {
        const { web3 } = this;

        try {
            const networkId = await web3.eth.net.getId();
            const contracts_to_deploy = ['EUSD', 'sBNB', 'sTSLA', 'Mint', 'Swap', 'BNBPriceFeed', 'TSLAPriceFeed']
            const deployedNetworks = {};
            deployedNetworks['EUSD'] = EUSDArtifact.networks[networkId];//??
            deployedNetworks['sBNB'] = sBNBArtifact.networks[networkId];
            deployedNetworks['sTSLA'] = sTSLAArtifact.networks[networkId];
            deployedNetworks['Mint'] = MintArtifact.networks[networkId];
            deployedNetworks['Swap'] = SwapArtifact.networks[networkId];
            deployedNetworks['BNBPriceFeed'] = BNBPFArtifact.networks[networkId];
            deployedNetworks['TSLAPriceFeed'] = TSLAPFArtifact.networks[networkId];

            const contractABI = {}; // abi??
            contractABI['EUSD'] = EUSDArtifact.abi; //??
            contractABI['sBNB'] = sBNBArtifact.abi;
            contractABI['sTSLA'] = sTSLAArtifact.abi;
            contractABI['Mint'] = MintArtifact.abi;
            contractABI['Swap'] = SwapArtifact.abi;
            contractABI['BNBPriceFeed'] = BNBPFArtifact.abi;
            contractABI['TSLAPriceFeed'] = TSLAPFArtifact.abi;

            this.meta = {};
            for (name of contracts_to_deploy) {
                this.meta[name] = new web3.eth.Contract(
                    contractABI[name],
                    deployedNetworks[name].address,
                );
            }

            const accounts = await web3.eth.getAccounts();
            this.accounts = accounts;

            this.setup()
            this.refreshBalance();
        } catch (error) {
            console.error(error)
            console.error("Could not connect to contract or chain.");
        }
    },

    grantRoles: async function(contractName) {
        //https://docs.openzeppelin.com/contracts/2.x/api/access#MinterRole  ??
        let minterRole = await this.meta[contractName].methods.MINTER_ROLE().call();
        let burnerRole = await this.meta[contractName].methods.BURNER_ROLE().call();
        let minterGranted = await this.meta[contractName].methods.hasRole(minterRole, this.meta['Mint'].options.address).call();
        if (!minterGranted) {
            await this.meta[contractName].methods.grantRole(minterRole, this.meta['Mint'].options.address).send({from: this.accounts[0]});
            await this.meta[contractName].methods.grantRole(burnerRole, this.meta['Mint'].options.address).send({from: this.accounts[0]});
        }
    },

    registerAsset: async function(contractName, priceFeed)  {
        let registered = await this.meta['Mint'].methods.checkRegistered(this.meta[contractName].options.address).call();
        if (!registered) {
            await this.meta['Mint'].methods.registerAsset(
            this.meta[contractName].options.address, 
            2, 
            this.meta[priceFeed].options.address
            ).send({from: this.accounts[0]});
        }
        
    },

    setup: async function() {
        this.grantRoles('sBNB');
        this.grantRoles('sTSLA');
        this.registerAsset('sBNB', 'BNBPriceFeed');
        this.registerAsset('sTSLA', 'TSLAPriceFeed');
    },

    // refresh 作用？
    refreshBalance: async function() {
        this.refreshBalanceEUSD();
        this.refreshBalancesBNB();
        this.refreshBalancesTSLA();
        this.refreshReserves();
    },

    refreshBalanceEUSD: async function() {
        const balance = await this.meta['EUSD'].methods.balanceOf(this.accounts[0]).call();

        const balanceElement = document.getElementsByClassName("balanceEUSD")[0];
        balanceElement.innerHTML = (balance / 10**8).toFixed(8);
    },

    refreshBalancesTSLA: async function() {
        const balance = await this.meta['sTSLA'].methods.balanceOf(this.accounts[0]).call();

        const balanceElement = document.getElementsByClassName("balancesTSLA");
        for (let i = 0; i < 3; i += 1) {
            balanceElement[i].innerHTML = (balance / 10**8).toFixed(8);
        }
    },

    refreshBalancesBNB: async function() {
        const balance = await this.meta['sBNB'].methods.balanceOf(this.accounts[0]).call();
        console.log(balance);
        const balanceElement = document.getElementsByClassName("balancesBNB");
        for (let i = 0; i < 3; i += 1) {
            balanceElement[i].innerHTML = (balance / 10**8).toFixed(8);
        }
    },

    refreshReserves: async function() {
        const reserves = await this.meta['Swap'].methods.getReserves().call();

        const reserve0Element = document.getElementsByClassName("reservesBNB");
        reserve0Element[0].innerHTML = (reserves[0] / 10**8).toFixed(8);
        reserve0Element[1].innerHTML = (reserves[0] / 10**8).toFixed(8);
        const reserve1Element = document.getElementsByClassName("reservesTSLA");
        reserve1Element[0].innerHTML = (reserves[1] / 10**8).toFixed(8);
        reserve1Element[1].innerHTML = (reserves[1] / 10**8).toFixed(8);
    },

    approve: async function(contractName, to, amount) {
        await this.meta[contractName].methods.approve(to, amount).send({from: this.accounts[0]});
    },

    init: async function() {
        this.setStatus("Initiating transaction... (please wait)");
        const liquidity0 = parseInt(document.getElementById("liquidity0").value * 10**8).toString();
        const liquidity1 = parseInt(document.getElementById("liquidity1").value * 10**8).toString();

        await this.approve('sBNB', this.meta['Swap'].options.address, liquidity0);
        await this.approve('sTSLA', this.meta['Swap'].options.address, liquidity1);
        await this.meta['Swap'].methods.init(liquidity0, liquidity1).send({ from: this.accounts[0] });
        
        this.refreshBalance();
        this.setStatus("Transaction complete!");
        
    },

    checkShares: async function() {
        const shares = await this.meta['Swap'].methods.getShares(this.accounts[0]).call();
        const balanceElement = document.getElementsByClassName("shares")[0];
        balanceElement.innerHTML = shares;
    },

    checkPrice: async function() {
        const sAsset = document.getElementById("sAsset").value;
        const priceFeed = sAsset.slice(1) + 'PriceFeed';
        console.log(sAsset, priceFeed);
        const price = await this.meta[priceFeed].methods.getLatestPrice().call();
        const priceElement = document.getElementsByClassName("price")[0];
        priceElement.innerHTML = (price[0] / 10**8).toFixed(8);
    },

    setStatus: function(message) {
        const status = document.getElementById("status");
        status.innerHTML = message;
    },

    openPosition: async function() {
        this.setStatus("Initiating transaction... (please wait)");

        const sAsset = document.getElementById("sAsset").value;
        const deposit = parseInt(document.getElementById("deposit").value * 10**8).toString();
        const CR = parseInt(document.getElementById("CR").value).toString();
        console.log(sAsset, deposit, CR);
        await this.approve('EUSD', this.meta['Mint'].options.address, deposit);
        console.log("called approved");

        let token_address = this.meta[sAsset]._address;
        await this.meta['Mint'].methods.openPosition(deposit, token_address, CR).send({from: this.accounts[0]});
        console.log("called openPosition");

        this.refreshBalance();
        this.setStatus("Transaction complete!");
    },

    addLiquidity: async function() {
        this.setStatus("Initiating transaction... (please wait)");

        const liquidity0 = parseInt(document.getElementById("liquidity0").value * 10**8).toString();
        const liquidity1 = parseInt(document.getElementById("liquidity1").value * 10**8).toString();
        console.log(liquidity0, liquidity1);
        await this.approve('sBNB', this.meta['Swap'].options.address, liquidity0);
        await this.approve('sTSLA', this.meta['Swap'].options.address, liquidity1);
        await this.meta['Swap'].methods.addLiquidity(liquidity0).send({from: this.accounts[0]});

        this.refreshBalance();
        this.setStatus("Transaction complete!");
    },

    removeLiquidity: async function() {
        this.setStatus("Initiating transaction... (please wait)");

        const shares = parseInt(document.getElementById("shares").value * 10**8).toString();
        console.log(shares);
        await this.approve('sBNB', this.meta['Swap'].options.address, shares);
        await this.approve('sTSLA', this.meta['Swap'].options.address, shares);
        await this.meta['Swap'].methods.removeLiquidity(shares).send({from: this.accounts[0]});
        console.log("called removeLiquidity");

        this.refreshBalance();
        this.setStatus("Transaction complete!");
    },

    token0To1: async function() {
        this.setStatus("Initiating transaction... (please wait)");

        const swap0 = parseInt(document.getElementById("swap0").value * 10**8).toString();
        console.log(swap0);
        await this.approve('sBNB', this.meta['Swap'].options.address, swap0);
        await this.meta['Swap'].methods.token0To1(swap0).send({from: this.accounts[0]});

        this.refreshBalance();
        this.setStatus("Transaction complete!");
    },

    token1To0: async function() {
        this.setStatus("Initiating transaction... (please wait)");

        const swap1 = parseInt(document.getElementById("swap1").value * 10**8).toString();
        await this.approve('sTSLA', this.meta['Swap'].options.address, swap1);
        await this.meta['Swap'].methods.token1To0(swap1).send({from: this.accounts[0]});
        
        this.refreshBalance();
        this.setStatus("Transaction complete!");
    },

};

window.App = App;

window.addEventListener("load", function() {
    if (window.ethereum) {
        // use MetaMask's provider
        App.web3 = new Web3(window.ethereum);
        window.ethereum.enable(); // get permission to access accounts
    } else {
        console.warn(
            "No web3 detected. Falling back to http://localhost:8545. You should remove this fallback when you deploy live",
        );
        // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
        App.web3 = new Web3(
            new Web3.providers.HttpProvider("http://localhost:8545"),
        );
    }

    App.start();
});




