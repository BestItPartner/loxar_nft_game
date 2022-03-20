const express = require('express')
const app = express()
const path = require('path');

const port = 8080;
const baseUri = "https://gateway.pinata.cloud/ipfs/Qmai8sszECds2imkUTGtsL3GKRxpiUK9zJo7XZcJPK4aG4";
const chainId = 97;  // test bsc

const Web3 = require('web3');
const LXRNFT = require("../build/contracts/LXRNFT.json");
const web3 = new Web3(new Web3.providers.HttpProvider('https://data-seed-prebsc-1-s1.binance.org:8545'));
const contract = new web3.eth.Contract(LXRNFT.abi, LXRNFT.networks[chainId].address);
const { isNumeric } = require("./utils.js")

const NodeCache = require( "node-cache" );
const cache = new NodeCache({
    stdTTL: 600,
    checkperiod: 0,
    useClones: false,    
});

app.use(express.static(path.join(__dirname, 'client/build')));

function daysToDate(timestamp) {    
    if (timestamp > 0) {
        var date = new Date(timestamp * 1000);
        return date.toDateString();    
    }
    return "unlocked";
}

function getTokenJson(id, price, power, sale, locktime) {
    let level = "basic";        
    if (power >= 250 && power < 500) 
        level = "advanced";
    else if (power >= 500 && power < 1000)
        level = "epic";
    else if (power >= 1000 && power < 2000)
        level = "legendary";
    else
        level = "supereme";
    let image = (level == "supereme") ? "supereme.mp4" : level + ".png";
    let result = {
        id: id,
        name: "LXRNFT #" + id,
        description: "Loxar Game's NFT Token " + id,
        image: `${baseUri}/${image}`,
        attributes: [
            {
                "price": "Ether",
                "value": web3.utils.fromWei(price, "ether")
            },
            {
                "sale": "is enable for sale",
                "value": sale ? "yes" : "no"
            },
            {
                "level": "item leve",
                "value": level
            },
            {
                "power": "power leve",
                "value": power
            },
            {
                "locked": "enable date",
                "value": daysToDate(locktime)
            },
        ]
    }

    return result;
}

app.get('/token/:tokenId', async (req, res) => {
    let tokenId = req.params.tokenId

    if (!isNumeric(tokenId)) {
        res.sendStatus(404)
        return
    }

    res.setHeader('Content-Type', 'application/json');
    let value = cache.get(tokenId);
    if (value !== undefined){
        res.json(value)
        return
    }

    try {
        let { id, price, power, sale, locktime } = await contract.methods.tokenMeta(tokenId).call();
        let result = getTokenJson(id, price, power, sale, locktime);
        cache.set(tokenId, result);
        res.json(result)
    }
    catch(error) {
        console.log(error)
        res.sendStatus(404)
    }
})  

app.get('/mynfts/:owneraddress', async (req, res) => {
    let owner = req.params.owneraddress

    res.setHeader('Content-Type', 'application/json');

    try {
        let mynfts = await contract.methods.myNFTs().call({
            from: owner            
        });
        if (mynfts != null) {
            let result = [];
            for (let i = 0; i < mynfts.length; i++) {
                const tokenId = mynfts[i];
                let { id, price, power, sale } = await contract.methods.tokenMeta(tokenId).call();
                result.push(getTokenJson(id, price, power, sale));
            }            
            res.json(result)
        }        
    }
    catch(error) {
        console.log(error)
        res.sendStatus('[]')
    }
})  

app.listen(port, () => {
    console.log(`LXRNFT TokenURI listening port ${port}`)
})