// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MintClubToken.sol";

/**
* @title MintClub Token Factory
*
* Create an ERC20 token using proxy pattern to save gas
*/
abstract contract MintClubFactory is Ownable {
    /**
     *  ERC20 Token implementation contract
     *  We use "EIP-1167: Minimal Proxy Contract" in order to save gas cost for each token deployment
     *  REF: https://github.com/optionality/clone-factory
     */
    address public tokenImplementation;

    // Array of all created tokens
    address[] public tokens;

    // Token => Max Supply
    mapping (address => uint256) public maxSupply;

    event TokenCreated(address tokenAddress);

    constructor(address implementation) {
        tokenImplementation = implementation;
    }

    function updateTokenImplementation(address implementation) public onlyOwner {
        tokenImplementation = implementation;
    }

    // REF: https://github.com/optionality/clone-factory
    function _createClone(address target) private returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }

    function _createToken(string memory name, string memory symbol, uint256 maxTokenSupply) internal returns (address) {
        address tokenAddress = _createClone(tokenImplementation);
        MintClubToken newToken = MintClubToken(tokenAddress);
        newToken.init(name, symbol);

        tokens.push(tokenAddress);
        maxSupply[tokenAddress] = maxTokenSupply;

        emit TokenCreated(tokenAddress);

        return tokenAddress;
    }

    function tokenCount() external view returns (uint256) {
        return tokens.length;
    }

    function exists(address tokenAddress) public view returns (bool) {
        return maxSupply[tokenAddress] > 0;
    }
}
