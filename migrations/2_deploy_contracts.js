const colors = require('colors')
const LXR = artifacts.require('LXR.sol')
const LXRNFT = artifacts.require('LXRNFT.sol')
const LXRGAME = artifacts.require('LXRGame.sol')

const baseURI = "http://164.132.52.8:8080/token/";
const initLXRs = web3.utils.toWei('1000000');

const whitelist = [
  "0x09671368DdB64405d3F2E029E8c0DB9c80Ee7234", 
  "0x952aB40399Ab9CCEa8dd47653431872ebe1833A0",
  "0x342e92e74BD5Fe17eAF95eF40B9b6B3f5A37D8AF",
  "0x05Be88DD6e26162184D897557a6e6d9652Efced4",
  "0xe81fFb5FB51c8d779cAa08D0AC5231A7bb64d61D",
  "0x2c042e3c7469aE9108b878Eae960CE682b5FC03F",
  "0x6BF96694d3D52eD0Dfb68458c55B833f2DDFe142",
  "0x2a7409471f7069061C5eBd9fcFc83BC279A6B8b4",
  "0x4FE106B587d357b4A56f9881788369165242ee3B",
  "0x4e33F295D162F74dFa1f2D63996Ad37c9Da39c40",
  "0x7C310accB099fD18e2a5160d6fa4BEAEEe17E29C",
  "0x9a7D1a970441BA9F4D93E3793b79Fb7798C143d8",
  "0x23172374C12e3fc0D55c57f1e5dff470C873A025",
  "0x7b6ad7ae6E686678303F372bA6a7fBF482C3d2F6",
  "0xEDF2E1BF0E288F973ce6e2911f9b9A224710F550",
  "0x634eD3f5536B92d736C239211f40c1AF21338086",
  "0xe7641E519D9567EA65FE8D90cFB6bd4492CafDd7",
  "0xE2EcF937aFADA7A165C33E0d5beC78F6d8a9ebc5",
  "0x6F07471C1Eb70Bed09a92963F07F32c3Fb46aa23"
]

module.exports = async deployer => {  
  await deployer.deploy(LXR);
  const _lxr = await LXR.deployed();
  
  await deployer.deploy(LXRNFT);
  const _lxrnft = await LXRNFT.deployed();

  await deployer.deploy(LXRGAME, _lxr.address, _lxrnft.address);
  const _lxrgame = await LXRGAME.deployed();

  await _lxrnft.setBaseURI(baseURI);
  await _lxrnft.setLoxarGame(_lxrgame.address);
  await _lxr.transfer(_lxrgame.address, initLXRs);
  await _lxrnft.addWhitelist(whitelist);

  console.log(colors.red("LXR: ", _lxr.address));
  console.log(colors.red("LXR NFT: ", _lxrnft.address));
  console.log(colors.red("LXR GAME: ", _lxrgame.address));
}
