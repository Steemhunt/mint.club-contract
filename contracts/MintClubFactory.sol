// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SimpleMintClubToken.sol";

contract MintClubFactory is Ownable {
    /**
     *  @dev
     *  TODO: Integral
     *  y = 0.00017x + 0.000000000025x²  -0.00000000000000000017x³
     *
     *  Bonding Curve with Reserve Weight (RW)
     *      - RW = reserveBalance / marketCap
     *      - marketCap = price * tokenSupply
     *      - price = reserveBalance / (tokenSupply * RW)
     *
     *      > buyAmount = tokenSupply * ((1 + baseTokenDepositAmount / reserveBalance)^RW — 1)
     *      > sellAmount = reserveBalance * ((1 + tokensSold / totalSupply)^(1/RW) — 1)
     *  REF:
     *      - https://medium.com/thoughtchains/on-single-bonding-curves-for-continuous-token-models-a167f5ffef89
     *      - https://billyrennekamp.medium.com/converting-between-bancor-and-bonding-curve-price-formulas-9c11309062f5
     *      - https://storage.googleapis.com/website-bancor/2018/04/01ba8253-bancor_protocol_whitepaper_en.pdf
     *      - https://medium.com/simondlr/tokens-2-0-curved-token-bonding-in-curation-markets-1764a2e0bee5
     *      - https://blog.bancor.network/how-liquid-tokens-work-a4ba30f2482b
     */

    uint32 constant RESERVE_WEIGHT = 3333333; // represented in ppm (RW / 1e6)
    IERC20 BASE_TOKEN;

    /**
     *  ERC20 Token implementation contract
     *  We use "EIP-1167: Minimal Proxy Contract" in order to save gas cost for each token deployment
     *  REF: https://github.com/optionality/clone-factory
     */
    address public tokenImplementation;

    // Array of all created tokens
    address[] public tokens;

    struct Parameters {
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 reserveBalance;
    }
    // Token => Parameters
    mapping (address => Parameters) public parameters;

    event TokenCreated(address tokenAddress);

    constructor(address baseToken, address tokenImplementation_) {
        BASE_TOKEN = IERC20(baseToken);
        tokenImplementation = tokenImplementation_;
    }

    function updateTokenImplementation(address tokenImplementation_) public onlyOwner {
        tokenImplementation = tokenImplementation_;
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
        SimpleMintClubToken(token).init(name, symbol);

        // TODO: Use MintClubToken with openzeppelin implementation instead of SimpleMintClubToken
        // and compare the gas cost

        address tokenAddress = address(token);
        tokens.push(tokenAddress);
        parameters[tokenAddress].maxSupply = maxSupply;

        emit TokenCreated(tokenAddress);
    }

    function tokenCount() public view returns (uint256) {
        return tokens.length;
    }

    // TODO:
    // price = reserveBalance / (tokenSupply * CW)
    function currentPrice(address tokenAddress) public view returns (uint256) {
        if (parameters[tokenAddress].reserveBalance == 0) {
            return 0;
        }

        return parameters[tokenAddress].reserveBalance / (parameters[tokenAddress].currentSupply * (RESERVE_WEIGHT / 1e6));
    }

    /** TODO:
     *  Formula:
     *  Return = supply * ((1 + baseTokenDepositAmount / reserveBalance) ^ (reserveWeight / 1000000) - 1)
     */
    function calculatePurchaseReturn(address tokenAddress, uint256 baseTokenDepositAmount) public view returns (uint256) {
        return parameters[tokenAddress].currentSupply * ((1 + baseTokenDepositAmount / parameters[tokenAddress].reserveBalance)**(RESERVE_WEIGHT / 1e6) - 1);
    }

    /** TODO:
     *  Formula:
     *  Return = reserveBalance * (1 - (1 - sellAmount / supply) ^ (1 / (reserveWeight / 1000000)))
     */
    function calculateSaleReturn(address tokenAddress, uint256 sellAmount) public view returns (uint256) {

    }
}
