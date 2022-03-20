// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LXR is ERC20, Ownable, ReentrancyGuard {
    constructor () public ERC20("Loxarian", "LXR") {
        _mint(msg.sender, 2000000 * (10 ** uint256(decimals())));
    }
}