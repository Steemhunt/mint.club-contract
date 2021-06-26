// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

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
    uint256 private constant MAX_SUPPLY_LIMIT = 1000000 * 1e18; // Where it requires 100M HUNT tokens as collateral

    event TokenCreated(address tokenAddress, string name, string symbol, uint256 maxTokenSupply);
    event ImplementationUpdated(address tokenImplementation);

    constructor(address implementation) {
        updateTokenImplementation(implementation);
    }

    // NOTE: This won't change the implementation of tokens that already created
    function updateTokenImplementation(address implementation) public onlyOwner {
        require(implementation != address(0), 'IMPLEMENTATION_CANNOT_BE_NULL');

        tokenImplementation = implementation;
        emit ImplementationUpdated(tokenImplementation);
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

    function createToken(string memory name, string memory symbol, uint256 maxTokenSupply) public returns (address) {
        require(maxTokenSupply > 0, 'MAX_SUPPLY_MUST_BE_POSITIVE');
        require(maxTokenSupply <= MAX_SUPPLY_LIMIT, 'MAX_SUPPLY_LIMIT_EXCEEDED');

        address tokenAddress = _createClone(tokenImplementation);
        MintClubToken newToken = MintClubToken(tokenAddress);
        newToken.init(name, symbol);

        tokens.push(tokenAddress);
        maxSupply[tokenAddress] = maxTokenSupply;

        emit TokenCreated(tokenAddress, name, symbol, maxTokenSupply);

        return tokenAddress;
    }

    function tokenCount() external view returns (uint256) {
        return tokens.length;
    }

    function exists(address tokenAddress) external view returns (bool) {
        return maxSupply[tokenAddress] > 0;
    }
}
