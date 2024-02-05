// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import  { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBTC is ERC20 {
    constructor(string memory _name, string memory _sign) ERC20(_name,_sign) {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}