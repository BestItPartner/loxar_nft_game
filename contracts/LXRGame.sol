// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import './LXR.sol';
import './LXRNFT.sol';
import './DateTimeLibrary.sol';

contract LXRGame is Ownable, ReentrancyGuard {    
    uint decimal = 18;
    uint256 public rewards = 1000000 * (10 ** decimal);
    uint256 public liquidity = 400000 * (10 ** decimal);
    uint256 public staking = 300000 * (10 ** decimal);
    uint256 public marketing = 160000 * (10 ** decimal);
    uint256 public reserve = 80000 * (10 ** decimal);
    uint256 public team = 40000 * (10 ** decimal);
    uint256 public airdrops = 20000 * (10 ** decimal);

    uint constant minPrice = 0.01 ether;
    uint constant beginfee = 45;
    uint constant dailyfee = 3;

    event getGameResult(address sender, uint rewardslxr, uint currate, uint winrate);
    event withdrawGameRewards(address sender, uint rewardslxr, uint day);

    uint nonce = 0;
    LXR lxrToken;
    LXRNFT lxrnftToken;

    struct Squad {
        address   player;
        uint      reward;                
        uint      hgstlv;
        uint      hgstwins;
        uint[]    nftIds;
    }

    Squad[] squads;    
    mapping(address => uint) usersLasttime;
    mapping(address => uint256[]) usersSquads;
    mapping(uint => uint) checkNftinSquad;
    bool isCheckOneday;

    mapping(address => uint) usersRewards;
    mapping(address => uint) usersLastDate;
    
    constructor(LXR _lxrToken, LXRNFT _lxrnftToken) public { 
        lxrToken = _lxrToken;
        lxrnftToken = _lxrnftToken;
        isCheckOneday = false;
    }
    
    function getAllSquads() external view onlyOwner returns (Squad[] memory) {
        return squads;
    }

    function changeContracts(LXR _lxrToken, LXRNFT _lxrnftToken) external onlyOwner 
    {
        lxrToken = _lxrToken;
        lxrnftToken = _lxrnftToken;
    }

    function changeCheckOneDay(bool flag) external onlyOwner {
        isCheckOneday = flag;
    }

    function getMaxAttackLimit(uint totalpower, uint level) internal view returns (uint _minap, uint _maxap) {
        if (level == 1 && totalpower >= 100) {
            _maxap = 300; _minap = 100;
        }
        else if (level == 2 && totalpower >= 150) {
            _maxap = 460; _minap = 150;
        }
        else if (level == 3 && totalpower >= 240) {
            _maxap = 720; _minap = 240;
        }
        else if (level == 4 && totalpower >= 370) {
            _maxap = 1110; _minap = 370;
        }
        else if (level == 5 && totalpower >= 570) {
            _maxap = 1710; _minap = 570;
        }
        else if (level == 6 && totalpower >= 880) {
            _maxap = 2640; _minap = 880;
        }
        else if (level == 7 && totalpower >= 1350) {
            _maxap = 4070; _minap = 1350;
        }
        else if (level == 8 && totalpower >= 2090) {
            _maxap = 6290; _minap = 2090;
        }
        else if (level == 9 && totalpower >= 3240) {
            _maxap = 9710; _minap = 3240;
        }
        else if (level == 10 && totalpower >= 5000) {
            _maxap = 15000; _minap = 5000;
        }
    }

    function getSquadInfo(uint[] memory _nftIds) internal view returns (uint count, uint totalpower, uint totalrarity) {        
        count = 0;
        totalpower = 0;
        totalrarity = 0;
        for (uint i = 0; i < _nftIds.length; i++) {
            if (_nftIds[i] > 0) {
                require(lxrnftToken.ownerOf(_nftIds[i]) == msg.sender, "Invalid token id not for the msg sender.");
                count++;

                uint rarity = 1;
                uint power = lxrnftToken.tokenMeta(_nftIds[i]).power;                              
                if (power >= 250 && power < 500) 
                    rarity = 2;
                else if (power >= 500 && power < 1000)
                    rarity = 3;
                else if (power >= 1000 && power < 2000)
                    rarity = 4; 
                else
                    rarity = 5;

                totalpower += power;
                totalrarity += rarity;
            }
        }      
    }

    function rand(uint256 min, uint256 max) internal returns (uint256){
        nonce++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, nonce))) % (min + max) - min;        
    }

    function createSquad(uint256[] memory _nftIds) external returns(uint256 squadid) {
        for (uint i = 0; i < _nftIds.length; i++) {
            require(lxrnftToken.ownerOf(_nftIds[i]) == msg.sender, "Not valid NFT id for the msg sender.");
            require(checkNftinSquad[_nftIds[i]] == 0, "Found an NFT id that joined in another squad.");            
        }
        squadid = squads.length;
        Squad storage _squad = squads.push();
        _squad.player = msg.sender;
        _squad.reward = 0;
        _squad.hgstlv = 1;
        _squad.hgstwins = 0;
        _squad.nftIds = _nftIds;
        usersSquads[msg.sender].push(squadid);
        for (uint i = 0; i < _nftIds.length; i++) {
           checkNftinSquad[_nftIds[i]] = squadid + 1; 
        }
    }

    function deleteSquad(uint squadid) external {
        require(squadid < squads.length, "Invalid squad id.");
        require(squads[squadid].player == msg.sender, "Invalid owner for the squad.");
        for (uint i = 0; i < squads[squadid].nftIds.length; i++) {
            checkNftinSquad[squads[squadid].nftIds[i]] = 0; 
        }        
        Squad storage _squad = squads[squadid];        
        delete _squad.nftIds;
        delete squads[squadid];  

        uint _length = usersSquads[msg.sender].length;
        for (uint i = 0; i < _length; i++) {
            if (usersSquads[msg.sender][i] == squadid) {
                for (uint j = i; j < _length - 1; j++) {
                    usersSquads[msg.sender][j] = usersSquads[msg.sender][j + 1];
                }
                usersSquads[msg.sender].pop();
                break;
            }
        }
    }

    function updateSquad(uint256 squadid, uint256[] memory _nftIds) external returns(bool result) {
        require(squadid < squads.length, "Invalid squad id.");
        require(squads[squadid].player == msg.sender, "Invalid owner for the squad.");
        
        for (uint i = 0; i < _nftIds.length; i++) {
            require(lxrnftToken.ownerOf(_nftIds[i]) == msg.sender, "Not valid NFT id for the msg sender.");
            require(checkNftinSquad[_nftIds[i]] == 0 || checkNftinSquad[_nftIds[i]] == (squadid + 1), "Found an NFT id that joined in another squad.");            
        }
        for (uint i = 0; i < squads[squadid].nftIds.length; i++) {
            checkNftinSquad[squads[squadid].nftIds[i]] = 0; 
        }   
        for (uint i = 0; i < _nftIds.length; i++) {
           checkNftinSquad[_nftIds[i]] = squadid + 1; 
        }

        Squad storage _squad = squads[squadid];        
        delete _squad.nftIds;
        _squad.nftIds = _nftIds;
    }

    function getMySquadIds() external view returns (uint[] memory mysquads) {        
        mysquads = usersSquads[msg.sender];
    }

    function getSquadFromId(uint squadid) external view returns (uint hgstlv, uint hgstwins, uint totalpower, uint totalrarity, uint[] memory nftIds) {
        require(squadid < squads.length, "Invalid id");
        require(squads[squadid].player == msg.sender, "Invalid squad owner");

        hgstlv = squads[squadid].hgstlv;
        hgstwins = squads[squadid].hgstwins;
        nftIds = squads[squadid].nftIds;

        totalpower = 0;
        totalrarity = 0;
        for (uint i = 0; i < nftIds.length; i++) {
            uint rarity = 1;
            uint power = 250;
            power = lxrnftToken.tokenMeta(nftIds[i]).power;                              
            if (power >= 250 && power < 500) 
                rarity = 2;
            else if (power >= 500 && power < 1000)
                rarity = 3;
            else if (power >= 1000 && power < 2000)
                rarity = 4; 
            else
                rarity = 5;
            totalpower += power;
            totalrarity += rarity;
        }      
    }

    function playGame(uint squadid, uint level) external payable returns (uint rewardslxr, uint currate) {      
        require(msg.value >= minPrice, "Price is insufficient than minimum value (0.01BNB).");       
        require(squadid < squads.length, "Invalid squad id");
        require(level > 0 && level <= 10, "Invalid level: 1~10 enabled.");

        uint enabletime = DateTimeLibrary.addDays(usersLasttime[msg.sender], 1);        
        if (isCheckOneday) {
            require(enabletime <= block.timestamp, "You can play once per day with the squad.");
        }        

        if (level > squads[squadid].hgstlv + 1) {
            revert("Locked level, win 3 more times in lower level.");    
        }
        else if (level == (squads[squadid].hgstlv + 1) && squads[squadid].hgstwins < 3) {
            revert("Locked level, win 3 more times in lower level.");            
        }

        uint256 totalpower = 0;
        uint256 totalrarity = 0;
        uint256 counter = 0;        
        uint256 minap = 0;
        uint256 maxap = 0;
        (counter, totalpower, totalrarity) = getSquadInfo(squads[squadid].nftIds);
        (minap, maxap) = getMaxAttackLimit(totalpower, level);
        require(maxap > 0 && minap > 0, "Not satisfied in level and min attack condition.");
        
        if (totalpower > maxap)
            totalpower = maxap;        

        uint256 winrate = uint256(60 * (totalpower - minap) / (maxap - minap) + 20);

        // Calculate winning rate and rewards loxar tokens
        currate = uint256(rand(0, 100));
        if (currate <= winrate && totalpower > 0) {
            // * 10 ^ 4 preprocessing
            rewardslxr = ((10 ** (decimal - 4)) * (totalpower * 90 +  totalrarity * 3900 - 8800)) / 5;            
        } else {
            rewardslxr = 0;
        }

        require(rewardslxr <= rewards, "LXR token is  not sufficient for rewards");                      
        // Lock all NFT tokens in playing squad.
        for (uint i = 0; i < squads[squadid].nftIds.length; i++) {
            lxrnftToken.setTokenLocked(squads[squadid].nftIds[i], true);
        }
        // Update the last playing time.
        usersLasttime[msg.sender] = block.timestamp;                       
        if (rewardslxr > 0) {            
            Squad storage _squad = squads[squadid]; 
            _squad.reward = rewardslxr;
            if (_squad.hgstlv == level) {
                _squad.hgstwins++;
            }
            else if (_squad.hgstlv < level) {
                _squad.hgstlv = level;
                _squad.hgstwins = 1;
            }           
            uint totalrewards = usersRewards[msg.sender] + rewardslxr;
            usersRewards[msg.sender] = totalrewards;
            if (usersLastDate[msg.sender] == 0) {
                usersLastDate[msg.sender] = block.timestamp;
            }
        }
        emit getGameResult(msg.sender, rewardslxr, currate, winrate);
    }
    
    function getAvailableRewards() external view returns (uint) {
        return usersRewards[msg.sender];
    }

    function getLastWithdrawDateTime() external view returns (uint year, uint month, uint day, uint hour, uint minute, uint second) {        
        (year, month, day, hour, minute, second) = DateTimeLibrary.timestampToDateTime(usersLastDate[msg.sender]);
    }

    function withdrawRewards() external nonReentrant returns (uint rewardslxr) {
        require(usersLastDate[msg.sender] > 0, "Invalid last date");
        require(usersRewards[msg.sender] > 0, "Insufficient rewards");

        rewardslxr = usersRewards[msg.sender];
        uint _days = DateTimeLibrary.diffDays(usersLastDate[msg.sender], block.timestamp);        
        if (_days < 15) {
            rewardslxr -= uint(rewardslxr * (beginfee - dailyfee * _days) / 100);
        }
        usersRewards[msg.sender] = 0;
        usersLastDate[msg.sender] = 0;
        rewards -= rewardslxr;
        lxrToken.transfer(msg.sender, rewardslxr);  

        emit withdrawGameRewards(msg.sender, rewardslxr, _days);              
    }

    function withdrawEther(uint256 amount) external payable onlyOwner {
        require(amount <= address(this).balance, "insufficent Ethers");
        payable(msg.sender).transfer(amount);
    }

    function withdrawLXR(uint amount) external onlyOwner {
        require(amount <= lxrToken.balanceOf(address(this)), "insufficent LXR tokens");
        lxrToken.transfer(msg.sender, amount);
    }
}
