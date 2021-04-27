// SPDX-License-Identifier: https://github.com/bancorprotocol/contracts-solidity/blob/v0.6.36/LICENSE

pragma solidity ^0.8.0;

import "./Power.sol"; // Efficient power function.

/**
* @title Bancor formula by Bancor
*
* Licensed to the Apache Software Foundation (ASF) under one or more contributor license agreements;
* and to You under the Apache License, Version 2.0. "
*/
abstract contract BancorFormula is Power {
    uint32 internal constant MAX_WEIGHT = 1000000;

    // TODO:
    // If we're going to use y = x^2 permanently, we don't need to use this complicated power function
    // because: ∫(x^2)dx (1->a) = (a^3/3) - (1/3)
    // Let's optimize it once we decided what curve we're going to use

    /**
     * @dev given a token supply, reserve balance, weight and a deposit amount (in the reserve token),
     * calculates the target amount for a given conversion (in the main token)
     *
     * Formula:
     * return = _supply * ((1 + _amount / _reserveBalance) ^ (_reserveWeight / MAX_WEIGHT) - 1)
     *
     * @param _supply          liquid token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveWeight   reserve weight, represented in ppm (1-MAX_WEIGHT)
     * @param _amount          amount of reserve tokens to get the target amount for
     *
     * @return target
     */
    function purchaseTargetAmount(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveWeight,
        uint256 _amount
    ) internal view returns (uint256) {
        // validate input
        require(_supply > 0, "INVALID_SUPPLY");
        require(_reserveBalance > 0, "INVALID_RESERVE_BALANCE");
        require(_reserveWeight > 0 && _reserveWeight <= MAX_WEIGHT, "INVALID_RESERVE_WEIGHT");

        // special case for 0 deposit amount
        if (_amount == 0) return 0;

        // special case if the weight = 100%
        if (_reserveWeight == MAX_WEIGHT) return _supply * _amount / _reserveBalance;

        uint256 result;
        uint8 precision;
        uint256 baseN = _amount + _reserveBalance;
        (result, precision) = power(baseN, _reserveBalance, _reserveWeight, MAX_WEIGHT);
        uint256 temp = (_supply * result) >> precision;
        return temp - _supply;
    }

    /**
     * @dev given a token supply, reserve balance, weight and a sell amount (in the main token),
     * calculates the target amount for a given conversion (in the reserve token)
     *
     * Formula:
     * return = _reserveBalance * (1 - (1 - _amount / _supply) ^ (MAX_WEIGHT / _reserveWeight))
     *
     * @param _supply          liquid token supply
     * @param _reserveBalance  reserve balance
     * @param _reserveWeight   reserve weight, represented in ppm (1-MAX_WEIGHT)
     * @param _amount          amount of liquid tokens to get the target amount for
     *
     * @return reserve token amount
     */
    function saleTargetAmount(
        uint256 _supply,
        uint256 _reserveBalance,
        uint32 _reserveWeight,
        uint256 _amount
    ) internal view returns (uint256) {
        // validate input
        require(_supply > 0, "INVALID_SUPPLY");
        require(_reserveBalance > 0, "INVALID_RESERVE_BALANCE");
        require(_reserveWeight > 0 && _reserveWeight <= MAX_WEIGHT, "INVALID_RESERVE_WEIGHT");
        require(_amount <= _supply, "INVALID_AMOUNT");

        // special case for 0 sell amount
        if (_amount == 0) return 0;

        // special case for selling the entire supply
        if (_amount == _supply) return _reserveBalance;

        // special case if the weight = 100%
        if (_reserveWeight == MAX_WEIGHT) return _reserveBalance * _amount / _supply;

        uint256 result;
        uint8 precision;
        uint256 baseD = _supply - _amount;
        (result, precision) = power(_supply, baseD, MAX_WEIGHT, _reserveWeight);
        uint256 temp1 = _reserveBalance * result;
        uint256 temp2 = _reserveBalance << precision;
        return (temp1 - temp2) / result;
    }
}