// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MintClubToken.sol";

/**
* @title Token Forwarder
*
* Receive tokens from requesters and keep it until the owner accept the request
* Admin can change the owner address for tokens
*/
contract Forwarder is Ownable {
    uint256 public feeRate = 500; // 500 / 10,000 = 5% of bounty is taken when accepted
    address public fundAddress = address(0);

    // Token => Requester => bountyAmount
    mapping (address => mapping (address => uint256)) public pendingBounty;

    // Token => Owner
    mapping (address => address) public tokenOwner;

    event Request(address tokenAddress, address requester, uint256 amount);
    event Refund(address tokenAddress, address requester, uint256 amount);
    event Accept(address tokenAddress, address requester, address owner, uint256 amount);

    function updateFee(address _fundAddress, uint256 _feeRate) external onlyOwner {
        fundAddress = _fundAddress;
        feeRate = _feeRate;
    }

    function updateTokenOwner(address tokenAddress, address newOwner) external onlyOwner {
        tokenOwner[tokenAddress] = newOwner;
    }

    function request(address tokenAddress, uint256 amount) external {
        MintClubToken token = MintClubToken(tokenAddress);
        require(token.allowance(_msgSender(), address(this)) >= amount, 'NOT_ENOUGH_ALLOWANCE');

        require(token.transferFrom(_msgSender(), address(this), amount), 'TOKEN_TRANSFER_FAILED');
        pendingBounty[tokenAddress][_msgSender()] += amount;

        emit Request(tokenAddress, _msgSender(), amount);
    }

    function refund(address tokenAddress, uint256 amount) external {
        require(pendingBounty[tokenAddress][_msgSender()] >= amount, 'AMOUNT_LIMIT_EXCEEDED');

        pendingBounty[tokenAddress][_msgSender()] -= amount;
        require(MintClubToken(tokenAddress).transfer(_msgSender(), amount), 'REFUND_TRANSFER_FAILED');

        emit Refund(tokenAddress, _msgSender(), amount);
    }

    function accept(address tokenAddress, address requester, uint256 amount) external {
        require(_msgSender() == tokenOwner[tokenAddress], 'PERMISSION_DENIED');
        require(pendingBounty[tokenAddress][requester] >= amount, 'AMOUNT_LIMIT_EXCEEDED');

        pendingBounty[tokenAddress][requester] -= amount;

        MintClubToken token = MintClubToken(tokenAddress);
        uint256 fee = amount * feeRate / 10000;

        require(token.transfer(_msgSender(), amount - fee), 'BOUNTY_TRANSFER_FAILED');
        require(token.transfer(fundAddress, fee), 'FEE_TRANSFER_FAILED');

        emit Accept(tokenAddress, requester, _msgSender(), amount);
    }
}
