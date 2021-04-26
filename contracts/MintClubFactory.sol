// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MintClubToken.sol";

/**
* @title MintClub Token Factory
*
* Create an ERC20 token using proxy pattern to save gas
*/
contract MintClubFactory is Ownable {
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

    constructor(address baseToken, address implementation) {
        BASE_TOKEN = IERC20(baseToken);
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

    function createToken(string memory name, string memory symbol, uint256 maxSupply) public {
        address token = _createClone(tokenImplementation);
        MintClubToken(token).init(name, symbol);

        address tokenAddress = address(token);
        tokens.push(tokenAddress);
        maxSupply[tokenAddress] = maxSupply;

        emit TokenCreated(tokenAddress);
    }

    function tokenCount() public view returns (uint256) {
        return tokens.length;
    }

    function exists(address tokenAddress) public view returns (bool) {
        return maxSupply[tokenAddress] > 0;
    }
}
