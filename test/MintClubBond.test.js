const { ether, BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256, ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubBond = artifacts.require('MintClubBond');

contract('MintClubBond', function(accounts) {
  const [ deployer, alice, bob ] = accounts;

  const ORIGINAL_BALANCE_A = new BN('700000000000'); // 700B
  const ORIGINAL_BALANCE_B = new BN('100000000000'); // 100B
  const TOTAL_RESERVE_SUPPLY = ORIGINAL_BALANCE_A.add(ORIGINAL_BALANCE_B);
  const MAX_SUPPLY = new BN('1000000');

  const BENEFICIARY = '0x32A935f79ce498aeFF77Acd2F7f35B3aAbC31a2D';
  const DEFAULT_BENEFICIARY = '0x82CA6d313BffE56E9096b16633dfD414148D66b1';

  // We need to put a little bit more Reserve Tokens than the table values due to 0.3% buy tax
  const calculateReserveWithTax = function(reserveAmount, inEther = false) {
    if (!inEther) {
      reserveAmount = ether(reserveAmount);
    }
    const reserveWithTax = reserveAmount.mul(new BN('1000')).div(new BN('997'));

    return [reserveWithTax, reserveWithTax.sub(reserveAmount)]; // return [reserve, tax]
  };

  beforeEach(async function() {
    this.reserveToken = await MintClubToken.new();
    await this.reserveToken.init('Reserve Token', 'RESERVE');

    await this.reserveToken.mint(alice, ether(ORIGINAL_BALANCE_A));
    await this.reserveToken.mint(bob, ether(ORIGINAL_BALANCE_B));

    const tokenImplimentation = await MintClubToken.new();
    this.bond = await MintClubBond.new(this.reserveToken.address, tokenImplimentation.address);

    const receipt = await this.bond.createToken('New Token', 'NEW', ether(MAX_SUPPLY));
    this.token = await MintClubToken.at(receipt.logs[1].args.tokenAddress);

    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: alice });
    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: bob });
  });

  it('should revert on an invalid token address', async function() {
    await expectRevert(
      this.bond.buy(ZERO_ADDRESS, '1', 0, BENEFICIARY, { from: alice }),
      'TOKEN_NOT_FOUND'
    );
  })

  it('should have infinite allowance', async function() {
    expect(await this.reserveToken.allowance(alice, this.bond.address, { from: alice })).to.be.bignumber.equal(MAX_UINT256);
  });

  it('initial token price', async function() {
    expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal('0');
  });

  it('should have initial reserve balance', async function() {
    expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal('0');
  });

  describe('createAndBuy', function() {
    beforeEach(async function() {
      const values = calculateReserveWithTax('500000');
      this.reserveWithTax = values[0];
      this.tax = values[1];

      // Create and buy 500,000 MINT worth of tokens in the beginning
      const receipt = await this.bond.createAndBuy('New Token 2', 'NEW2', ether(MAX_SUPPLY), this.reserveWithTax, BENEFICIARY, { from: alice });
      const tokenAddress = receipt.logs[1].args.tokenAddress;
      this.token = await MintClubToken.at(tokenAddress);
    });

    it('has correct pool reserve balance', async function() {
      expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether('500000'));
    });

    it('has correct total supply', async function() {
      expect(await this.token.totalSupply()).to.be.bignumber.equal(ether('1000'));
    });

    it('increases the price per token', async function() {
      expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether('1000'));
    });

    it('gives user a correct balance', async function() {
      expect(await this.token.balanceOf(alice)).to.be.bignumber.equal(ether('1000'));
    });

    it('reduces the reserve token balance of user', async function() {
      const newBalance = ether(ORIGINAL_BALANCE_A).sub(this.reserveWithTax);
      expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(newBalance);
    });

    it('gives beneficiary comission', async function() {
      expect(await this.reserveToken.balanceOf(BENEFICIARY)).to.be.bignumber.equal(this.tax);
    });
  }); // END: createAndBuy

  /**
   * REF: Price calculation
   * https://docs.google.com/spreadsheets/d/1BbkFrhD3R7waPPw8ZmY5qHrJIe-umJksnsJRsNGRTl4/edit?usp=sharing
   *
   * TokenSupply | Price    | Reserve Balance
   * ----------- | -------- | ---------------
   */
  const TABLE = [
    [ '1'        , '1'       , '0.5'          ],
    [ '10'       , '10'      , '50'           ],
    [ '100'      , '100'     , '5000'         ],
    [ '500'      , '500'     , '125000'       ],
    [ '1000'     , '1000'    , '500000'       ],
    [ '7000'     , '7000'    , '24500000'     ],
    [ '10000'    , '10000'   , '50000000'     ],
    [ '90000'    , '90000'   , '4050000000'   ],
    [ '100000'   , '100000'  , '5000000000'   ], // 5B = $20,000 (where 1 MINT = $0.000004)
    [ '800000'   , '800000'  , '320000000000' ],
    [ '1000000'  , '1000000' , '500000000000' ] // 500B = $2M
  ];

  describe('buy', function() {
    for (let i = 0; i < TABLE.length; i++) {
      describe(`up to ${TABLE[i][0]} tokens`, function() {
        beforeEach(async function() {
          // Buy tax: 0.3%
          const values = calculateReserveWithTax(TABLE[i][2]);
          this.reserveWithTax = values[0];
          this.tax = values[1];

          this.receipt = await this.bond.buy(this.token.address, this.reserveWithTax, 0, BENEFICIARY, { from: alice });
        });

        it('has correct pool reserve balance', async function() {
          expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][2]));
        });

        it('has correct total supply', async function() {
          expect(await this.token.totalSupply()).to.be.bignumber.equal(ether(TABLE[i][0]));
        });

        it('increases the price per token', async function() {
          expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][1]));
        });

        it('gives user a correct balance', async function() {
          expect(await this.token.balanceOf(alice)).to.be.bignumber.equal(ether(TABLE[i][0]));
        });

        it('reduces the reserve token balance of user', async function() {
          const newBalance = ether(ORIGINAL_BALANCE_A).sub(this.reserveWithTax);
          expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(newBalance);
        });

        it('gives beneficiary comission', async function() {
          expect(await this.reserveToken.balanceOf(BENEFICIARY)).to.be.bignumber.equal(this.tax);
        });

        it('should emit Buy event', async function() {
          expectEvent(this.receipt, 'Buy', {
            tokenAddress: this.token.address,
            buyer: alice,
            amountMinted: ether(TABLE[i][0]),
            reserveAmount: this.reserveWithTax,
            beneficiary: BENEFICIARY,
            taxAmount: this.tax
          });
        });

        if (i < TABLE.length - 2) { // Prevent EXCEEDED_MAX_SUPPLY
          describe(`another purchase -> up to ${TABLE[i + 1][0]} tokens`, function() {
            beforeEach(async function() {
              const values = calculateReserveWithTax(ether(TABLE[i + 1][2]).sub(ether(TABLE[i][2])), true);
              await this.bond.buy(this.token.address, values[0], 0, BENEFICIARY, { from: alice });
            });

            it('has correct pool reserve balance', async function() {
              expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i + 1][2]));
            });

            it('has correct total supply', async function() {
              expect(await this.token.totalSupply()).to.be.bignumber.equal(ether(TABLE[i + 1][0]));
            });

            it('increases the price per token', async function() {
              expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[i + 1][1]));
            });

            it('gives user a correct balance', async function() {
              expect(await this.token.balanceOf(alice)).to.be.bignumber.equal(ether(TABLE[i + 1][0]));
            });
          });
        }
      });
    }

    describe('edge cases', function() {
      it('cannot be over max supply limit', async function() {
        const [MAX_COLLATERAL, ] = calculateReserveWithTax(TABLE.filter(t => t[0] === String(MAX_SUPPLY))[0][2]);
        await expectRevert(
          this.bond.buy(this.token.address, MAX_COLLATERAL.add(ether('1')), 0, BENEFICIARY, { from: alice }),
          'EXCEEDED_MAX_SUPPLY',
        );

        // Should not revert
        await this.bond.buy(this.token.address, MAX_COLLATERAL, 0, BENEFICIARY, { from: alice });
      });

      it('send fee to default beneficiary if beneficiary is not set', async function() {
        await this.bond.buy(this.token.address, ether('1'), 0, ZERO_ADDRESS, { from: alice });

        expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(ether(ORIGINAL_BALANCE_A).sub(ether('1')));
        expect(await this.reserveToken.balanceOf(DEFAULT_BENEFICIARY)).to.be.bignumber.equal(ether('0.003')); // 0.3%
      });

      it('should revert if minReward is not satisfied on buy', async function() {
        const buyAmount = calculateReserveWithTax('5000')[0];

        // 100 tokens = 5000 MINT
        await expectRevert(
          this.bond.buy(this.token.address, buyAmount, ether('100').addn(1), BENEFICIARY, { from: alice }),
          'SLIPPAGE_LIMIT_EXCEEDED'
        );

        // Should not revert
        await this.bond.buy(this.token.address, buyAmount, ether('100'), BENEFICIARY, { from: alice });
      });
    }); // edge cases
  }); // buy

  describe('sell', function() {
    for (let i = TABLE.length - 1; i > 0; i--) {
      describe(`from ${TABLE[i][0]} tokens`, function() {
        beforeEach(async function() {
          const [reserveAmountWithTax, ] = calculateReserveWithTax(TABLE[i][2]);
          await this.bond.buy(this.token.address, reserveAmountWithTax, 0, ZERO_ADDRESS, { from: alice });
          await this.token.approve(this.bond.address, MAX_UINT256, { from: alice });

          this.aliceBalanceBeforeSell = await this.reserveToken.balanceOf(alice);
          this.sellAmount = ether(new BN(TABLE[i][0]).sub(new BN(TABLE[i - 1][0])));
          this.receipt = await this.bond.sell(this.token.address, this.sellAmount, 0, BENEFICIARY, { from: alice });

          this.reserveRefunded = ether(TABLE[i][2]).sub(ether(TABLE[i - 1][2]));
          this.sellTax = this.reserveRefunded.mul(new BN('13')).div(new BN('1000')); // 1.3% sell tax
        });

        it('has correct pool reserve balance', async function() {
          expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 1][2]));
        });

        it('has correct total supply', async function() {
          expect(await this.token.totalSupply()).to.be.bignumber.equal(ether(TABLE[i - 1][0]));
        });

        it('decreases the price per token', async function() {
          expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 1][1]));
        });

        it('reduces the balance of user', async function() {
          expect(await this.token.balanceOf(alice)).to.be.bignumber.equal(ether(TABLE[i - 1][0]));
        });

        it('increase the reserve token balance of user', async function () {
          expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(
            this.aliceBalanceBeforeSell.add(this.reserveRefunded).sub(this.sellTax)
          );
        });

        it('gives beneficiary comission', async function() {
          expect(await this.reserveToken.balanceOf(BENEFICIARY)).to.be.bignumber.equal(this.sellTax);
        });

        it('should emit Sell event', async function() {
          expectEvent(this.receipt, 'Sell', {
            tokenAddress: this.token.address,
            seller: alice,
            amountBurned: this.sellAmount,
            refundAmount: this.reserveRefunded.sub(this.sellTax),
            beneficiary: BENEFICIARY,
            taxAmount: this.sellTax
          });
        });

        if (i > 2) {
          describe(`another sell -> to ${TABLE[i - 1][0]} tokens`, function() {
            beforeEach(async function() {
              this.aliceBalanceBeforeSell2 = await this.reserveToken.balanceOf(alice);

              const sellAmount = ether(new BN(TABLE[i - 1][0]).sub(new BN(TABLE[i - 2][0])));
              await this.bond.sell(this.token.address, sellAmount, 0, BENEFICIARY, { from: alice });
            });

            it('has correct pool reserve balance', async function() {
              expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 2][2]));
            });

            it('has correct total supply', async function() {
              expect(await this.token.totalSupply()).to.be.bignumber.equal(ether(TABLE[i - 2][0]));
            });

            it('decreases the price per token', async function() {
              expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 2][1]));
            });

            it('reduces the balance of user', async function() {
              expect(await this.token.balanceOf(alice)).to.be.bignumber.equal(ether(TABLE[i - 2][0]));
            });

            it('increase the reserve token balance of user', async function () {
              const refundAmount = ether(TABLE[i - 1][2]).sub(ether(TABLE[i - 2][2]));
              const sellTax = refundAmount.mul(new BN('13')).div(new BN('1000')); // 1.3% sell tax

              expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(
                this.aliceBalanceBeforeSell2.add(refundAmount).sub(sellTax)
              );
            });
          });
        }
      });
    }

    describe(`edge cases`, function() {
      beforeEach(async function() {
        this.row = TABLE[TABLE.length - 2];

        const buyAmount = calculateReserveWithTax(this.row[2])[0];
        await this.bond.buy(this.token.address, buyAmount, 0, BENEFICIARY, { from: alice });
        this.buyAmountAfterTax = await this.bond.reserveBalance(this.token.address); // 0.997
        await this.token.approve(this.bond.address, MAX_UINT256, { from: alice });

        this.balance = await this.token.balanceOf(alice); // should be this.row[0]
        this.sellTax = this.buyAmountAfterTax.mul(new BN('13')).div(new BN('1000')); // 1.3% sell tax
      });

      it('cannot sell more than user balance', async function () {
        await this.bond.buy(this.token.address, ether('1.00'), 0, BENEFICIARY, { from: bob }); // To prevent tokenSupply < tokenAmount (reverting on getBurnRefund)

        await expectRevert(
          this.bond.sell(this.token.address, ether(this.row[0]).addn(1), 0, BENEFICIARY, { from: alice }),
          'ERC20: burn amount exceeds balance',
        );

        // Should not revert
        await this.bond.sell(this.token.address, ether(this.row[0]), 0, BENEFICIARY, { from: alice });
      });

      it('send fee to default beneficiary if beneficiary is not set', async function() {
        await this.bond.sell(this.token.address, this.balance, 0, ZERO_ADDRESS, { from: alice }); // Sell all tokens (should return all reserve)

        expect(await this.reserveToken.balanceOf(DEFAULT_BENEFICIARY)).to.be.bignumber.equal(this.sellTax); // 1.3%
      });

      it('should revert if minReward is not satisfied on sell', async function() {
        await expectRevert(
          this.bond.sell(this.token.address, this.balance, this.buyAmountAfterTax.sub(this.sellTax).addn(1), BENEFICIARY, { from: alice }),
          'SLIPPAGE_LIMIT_EXCEEDED'
        );

        // Should not revert
        await this.bond.sell(this.token.address, this.balance, this.buyAmountAfterTax.sub(this.sellTax), BENEFICIARY, { from: alice });
      });
    }); // edge cases
  }); // sell
});