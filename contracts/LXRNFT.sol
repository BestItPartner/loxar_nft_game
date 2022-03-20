// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import './DateTimeLibrary.sol';

contract LXRNFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;  
    string baseURI;    
    uint mintPhases; 
    int usdPerNft; 
    address lxrgame;    
    mapping(address => bool) private whitelist;         
    mapping(address => uint) private _tokenCount;
    mapping (uint256 => TokenMeta) private _tokenMeta;
    AggregatorV3Interface internal priceFeedUsd;    
    AggregatorV3Interface internal priceFeedLxr;    

    struct TokenMeta {
        uint256 id;
        uint256 price;
        uint power;
        bool sale;        
        uint locktime;
    }

    /**
     * Chainlink for Oracle in BSC
     * Network: Binance Smart Chain
     * Aggregator 1: BNB/USD
     * Address: 0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE (Mainnet)
     * Address: 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526 (Testnet)
     * Aggregator 2: BNB/LXR
     * Address: 0x0 (Mainnet)
     * Address: 0x0 (Testnet)
     * Reference: https://docs.chain.link/docs/binance-smart-chain-addresses/
    */    
    constructor() ERC721("Loxarian NFT", "LXRT") {
        baseURI = "http://partybeavers.io:8080/token/";        
        usdPerNft = 200; // 200 usd
        mintPhases = 0; // 0: whitelist Sale, 1: public Sale, 2: normal Minting 
        priceFeedUsd = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        require(_tokenMeta[tokenId].locktime == 0 || _tokenMeta[tokenId].locktime < block.timestamp, "Token locked");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in child contracts.
     */
    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public virtual onlyOwner {
        baseURI = _newBaseURI;
    }

    function setLoxarGame(address _lxrgame) public onlyOwner {
        lxrgame = _lxrgame;
    }

    /**
     * @dev Minting Phases for starting Sales.     
     */
    function setMintPhases(uint _newmintPhases) public onlyOwner {
        mintPhases = _newmintPhases;
        if (mintPhases > 1) {
            usdPerNft = 10;
        }
    }

    function isWhitelist(address sender) public view returns (bool) {
        return whitelist[sender];        
    }

    function addWhitelist(address[] memory _whitelist) public onlyOwner {
        for (uint i = 0; i < _whitelist.length; i++) {
            whitelist[_whitelist[i]] = true;
        }
    }    

    function getAllOnSale () public view virtual returns( TokenMeta[] memory ) {
        uint256 counter = 0;
        for(uint i = 1; i < _tokenIds.current() + 1; i++) {
            if(_tokenMeta[i].sale == true) {
                counter++;
            }
        }
        TokenMeta[] memory tokensOnSale = new TokenMeta[](counter);
        counter = 0;
        for(uint i = 1; i < _tokenIds.current() + 1; i++) {
            if(_tokenMeta[i].sale == true) {
                tokensOnSale[counter] = _tokenMeta[i];
                counter++;
            }
        }
        return tokensOnSale;
    }

    /**
     * @dev sets maps token to its price
     * @param _tokenId uint256 token ID (token number)
     * @param _sale bool token on sale
     * @param _price unit256 token price
     * 
     * Requirements: 
     * `tokenId` must exist
     * `price` must be more than 0
     * `owner` must the msg.owner
     */
    function setTokenSale(uint256 _tokenId, bool _sale, uint256 _price) public {
        require(_exists(_tokenId), "No exist token");
        require(_price > 0, "Invalid price");
        require(ownerOf(_tokenId) == _msgSender());
        _tokenMeta[_tokenId].sale = _sale;
        _tokenMeta[_tokenId].price = _price;
    }

    function setTokenLocked(uint256 _tokenId, bool _lock) public {
        require(_exists(_tokenId), "No exist token");        
        require(ownerOf(_tokenId) == _msgSender() || lxrgame == _msgSender(), "Not allowed");
        uint locktime = DateTimeLibrary.addDays(block.timestamp, 1);  
        if (_lock)
            _tokenMeta[_tokenId].locktime = locktime;
        else 
            _tokenMeta[_tokenId].locktime = 0;        
    }

    /**
     * @dev sets maps token to its price
     * @param _tokenId uint256 token ID (token number)
     * @param _price uint256 token price
     * 
     * Requirements: 
     * `tokenId` must exist
     * `owner` must the msg.owner
     */
    function setTokenPrice(uint256 _tokenId, uint256 _price) public {
        require(_exists(_tokenId), "No exist token");
        require(ownerOf(_tokenId) == _msgSender());
        _tokenMeta[_tokenId].price = _price;
    }

    function tokenPrice(uint256 tokenId) public view virtual returns (uint256) {
        require(_exists(tokenId), "No exist token");
        return _tokenMeta[tokenId].price;
    }

    function tokenMintedCount() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    function myNFTs() public view virtual returns (uint256[] memory) {
        require(msg.sender != address(0), "Invalid address");

        uint256 counter = 0;
        for(uint i = 1; i < _tokenIds.current() + 1; i++) {
            if(msg.sender == ownerOf(i)) {
                counter++;
            }
        }
        uint256[] memory mytokens = new uint256[](counter);
        counter = 0;
        for(uint i = 1; i < _tokenIds.current() + 1; i++) {
            if(msg.sender == ownerOf(i)) {
                mytokens[counter] = i;
                counter++;
            }
        }
        return mytokens;
    }

    /**
     * @dev sets token meta
     * @param _tokenId uint256 token ID (token number)
     * @param _meta TokenMeta 
     * 
     * Requirements: 
     * `tokenId` must exist
     * `owner` must the msg.owner
     */
    function _setTokenMeta(uint256 _tokenId, TokenMeta memory _meta) private {
        require(_exists(_tokenId), "No exist token");        
        _tokenMeta[_tokenId] = _meta;
    }

    function tokenMeta(uint256 _tokenId) public view returns (TokenMeta memory) {
        require(_exists(_tokenId), "No exist token");        
        return _tokenMeta[_tokenId];
    }

    /**
     * @dev purchase _tokenId
     * @param _tokenId uint256 token ID (token number)
     */
    function purchaseToken(uint256 _tokenId) external payable nonReentrant {
        require(msg.sender != address(0) && msg.sender != ownerOf(_tokenId), "Invalid sender");
        require(msg.value >= _tokenMeta[_tokenId].price, "Insufficient price");
        require(_tokenMeta[_tokenId].sale == true, "Not allowed for sale");
        require(mintPhases == 2, "Not allowed now");
        
        address tokenSeller = ownerOf(_tokenId);

        // payable(tokenSeller).transfer(msg.value);
        (bool bSent, ) = payable(tokenSeller).call{value:msg.value}("");
        if (!bSent) {
            revert("Failed to send ether");
        }
        setApprovalForAll(tokenSeller, true);
        _transfer(tokenSeller, msg.sender, _tokenId);
        _tokenMeta[_tokenId].sale = false;
        
        _tokenCount[tokenSeller]--;
        _tokenCount[msg.sender]++;
    }

    function mintToken() external payable nonReentrant returns (uint256) {        
        require(msg.sender != address(0), "Invalid sender");                
        uint _price = uint(_getPrice(usdPerNft));

        if (mintPhases == 0) {
            require(_tokenIds.current() <= 5000, "Phase 1: overflowed 5000");
            require(isWhitelist(msg.sender) == true, "not whitelist address");    
            require(_tokenCount[msg.sender] < 5, "A whitelist can have maximum 5 NFTs");                
        }
        else if (mintPhases == 1) {
            require(_tokenIds.current() <= 10000, "Phase 2: overflowed 10000");
            require(_tokenCount[msg.sender] < 10, "A wallet can have maximum 10 NFTs");                
        }
        
        require(msg.value >= _price, "Insufficient price");

        payable(owner()).transfer(msg.value);        
        setApprovalForAll(owner(), true);
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _tokenCount[msg.sender]++;
        
        _setTokenMeta(newItemId, TokenMeta(newItemId, _price, _generateRandomPower(0), false, 0));        

        return newItemId;
    }
    
    function mintAdmin(address _to, uint256 _count) external onlyOwner
    {
        require(_to != address(0), "Invalid receiver");
        uint _price = uint(_getPrice(usdPerNft));

        for (uint256 i; i < _count; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            _mint(payable(_to), newItemId);
            _tokenCount[_to]++;
            
            _setTokenMeta(newItemId, TokenMeta(newItemId, _price, _generateRandomPower(i), false, 0));
        }
    }

    // Function to generate the hash value
    function _generateRandomPower(uint i) internal view returns (uint) 
    {        
        uint random = uint(keccak256(abi.encodePacked(block.timestamp, i)));
        uint group = uint(random % 100) + 1;
        uint power = 100;
        uint[] memory provs = new uint[](5);

        if (mintPhases == 0) {
            provs[0] = 0; provs[1] = 0; provs[2] = 60; provs[3] = 30; provs[4] = 10;
        }
        else if (mintPhases == 1) {
            provs[0] = 0; provs[1] = 75; provs[2] = 17; provs[3] = 6; provs[4] = 2;
        }
        else {
            provs[0] = 75; provs[1] = 17; provs[2] = 6; provs[3] = 2; provs[4] = 0;
        }

        if (group <= provs[0]) {                    // basic
            power = random % (250 - 100) + 100;
        }
        else if (group <= (provs[0] + provs[1])) {  // advanced
            power = random % (500 - 250) + 250;
        }
        else if (group <= (provs[0] + provs[1] + provs[2])) {   // epic
            power = random % (1000 - 500) + 500;
        }
        else if (group <= (provs[0] + provs[1] + provs[2] + provs[3])) {   // legendary
            power = random % (2000 - 1000) + 1000;
        }
        else {  // supereme
            power = random % (3000 - 2000) + 2000;
        }

        return power;        
    }

    // _usdPrice: USD Price * 100000000
    // _return: BNB Price (wei)
    function _getPrice(int _usdPrice) public view returns (int) 
    {
        if (mintPhases == 0) {
            return 400000000000000000;  // 0.4 BNB
        }
        else if (mintPhases == 1) {
            return 150000000000000000;  // 0.15 BNB
        }
        
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeedUsd.latestRoundData();
        return _usdPrice * (10 ** 26) / price;                
    }
}