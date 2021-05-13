const { ether, BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256, ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubBond = artifacts.require('MintClubBond');

contract('MintClubBond', function(accounts) {
  const [ deployer, alice, bob ] = accounts;

  const ORIGINAL_BALANCE_A = new BN('200000000');
  const ORIGINAL_BALANCE_B = new BN('1');
  const TOTAL_RESERVE_SUPPLY = ORIGINAL_BALANCE_A.add(ORIGINAL_BALANCE_B);
  const MAX_SUPPLY = new BN('100000');

  beforeEach(async function() {
    this.reserveToken = await MintClubToken.new();
    await this.reserveToken.init('Reserve Token', 'RESERVE');

    await this.reserveToken.mint(alice, ether(ORIGINAL_BALANCE_A));
    await this.reserveToken.mint(bob, ether(ORIGINAL_BALANCE_B));

    const tokenImplimentation = await MintClubToken.new();
    this.bond = await MintClubBond.new(this.reserveToken.address, tokenImplimentation.address);

    this.receipt = await this.bond.createToken('New Token', 'NEW', ether(MAX_SUPPLY));
    this.token = await MintClubToken.at(this.receipt.logs[0].args.tokenAddress);

    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: alice });
    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: bob });
  });

  it('should have infinite allowance', async function() {
    expect(await this.reserveToken.allowance(alice, this.bond.address, { from: alice })).to.be.bignumber.equal(MAX_UINT256);
  });

  it('initial token price', async function() {
    expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal('0');
  });

  it('should have initial reserve balance', async function() {
    expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal('0');
  });

  /**
   * REF: Price calculation
   * https://docs.google.com/spreadsheets/d/1BbkFrhD3R7waPPw8ZmY5qHrJIe-umJksnsJRsNGRTl4/edit?usp=sharing
   *
   * TokenSupply | Price    | Reserve Balance
   * ----------- | -------- | ---------------
   */
  const TABLE = [
    [ '1'        , '0.020'  , '0.01'      ],
    [ '10'       , '0.200'  , '1.00'      ],
    [ '100'      , '2.000'  , '100'       ],
    [ '500'      , '10.00'  , '2500'      ],
    [ '1000'     , '20.00'  , '10000'     ],
    [ '7000'     , '140.0'  , '490000'    ],
    [ '10000'    , '200.0'  , '1000000'   ],
    [ '90000'    , '1800.0' , '81000000'  ],
    [ '100000'   , '2000.0' , '100000000' ]
  ];
  const REFERRAL_ADDRESS = '0x32A935f79ce498aeFF77Acd2F7f35B3aAbC31a2D';

  // We need to put a little bit more Reserve Tokens than the table values due to 0.3% buy tax
  const calculateReserveWithTax = function(reserveAmount) {
    const reserveWithTax = ether(reserveAmount).mul(new BN('1000')).div(new BN('997'));

    return [reserveWithTax, reserveWithTax.sub(ether(reserveAmount))];
  };

  describe('buy', function() {
    for (let i = 0; i < TABLE.length; i++) {
      describe(`up to ${TABLE[i][0]} tokens`, function() {
        beforeEach(async function() {
          // Buy tax: 0.3%
          const values = calculateReserveWithTax(TABLE[i][2]);
          this.reserveWithTax = values[0];
          this.tax = values[1];

          await this.bond.buy(this.token.address, this.reserveWithTax, 0, REFERRAL_ADDRESS, { from: alice });
        });

        it('has correct pool reserve balance', async function() {
          expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][2]));
        });

        it('has correct total supply', async function() {
          expect(await this.bond.tokenSupply(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][0]));
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

        it('gives referral comission', async function() {
          expect(await this.reserveToken.balanceOf(REFERRAL_ADDRESS)).to.be.bignumber.equal(this.tax);
        });
      });
    }

    it('cannot be over max supply limit', async function() {
      const [MAX_COLLATERAL, ] = calculateReserveWithTax(TABLE.filter(t => t[0] === String(MAX_SUPPLY))[0][2]);
      await expectRevert(
        this.bond.buy(this.token.address, MAX_COLLATERAL.add(ether('1')), 0, REFERRAL_ADDRESS, { from: alice }),
        'EXCEEDED_MAX_SUPPLY',
      );

      // Should not revert
      await this.bond.buy(this.token.address, MAX_COLLATERAL, 0, REFERRAL_ADDRESS, { from: alice });
    });

    it('burns referral comission if referral is not set', async function() {
      await this.bond.buy(this.token.address, ether('1'), 0, ZERO_ADDRESS, { from: alice });

      expect(await this.reserveToken.totalSupply()).to.be.bignumber.equal(
        ether(TOTAL_RESERVE_SUPPLY).sub(ether('0.003')) // 0.3% burnt
      );
      expect(await this.reserveToken.balanceOf(alice)).to.be.bignumber.equal(ether(ORIGINAL_BALANCE_A).sub(ether('1')));
    });

    it('should revert if minReward is not satisfied', async function() {
      // Buy 10 tokens = 1 reserve token required
      const [reserveAmount, ] = calculateReserveWithTax('1.0');
      expectRevert(
        this.bond.buy(this.token.address, reserveAmount, ether('10').addn(1), REFERRAL_ADDRESS, { from: alice }),
        'SLIPPAGE_LIMIT_EXCEEDED'
      );

      // Should not revert
      this.bond.buy(this.token.address, reserveAmount, ether('10'), REFERRAL_ADDRESS, { from: alice });
    });
  });

  describe('sell', function() {
    for (let i = TABLE.length - 1; i > 0; i--) {
      describe(`from ${TABLE[i][0]} tokens`, function() {
        beforeEach(async function() {
          const [reserveAmountWithTax, ] = calculateReserveWithTax(TABLE[i][2]);
          await this.bond.buy(this.token.address, reserveAmountWithTax, 0, ZERO_ADDRESS, { from: alice });
          await this.token.approve(this.bond.address, MAX_UINT256, { from: alice });

          this.aliceBalanceBeforeSell = await this.reserveToken.balanceOf(alice);
          const sellAmount = ether(new BN(TABLE[i][0]).sub(new BN(TABLE[i - 1][0])));
          await this.bond.sell(this.token.address, sellAmount, 0, REFERRAL_ADDRESS, { from: alice });

          this.reserveRefunded = ether(TABLE[i][2]).sub(ether(TABLE[i - 1][2]));
          this.sellTax = this.reserveRefunded.mul(new BN('13')).div(new BN('1000')); // 1.3% sell tax
        });

        it('has correct pool reserve balance', async function() {
          expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 1][2]));
        });

        it('has correct total supply', async function() {
          expect(await this.bond.tokenSupply(this.token.address)).to.be.bignumber.equal(ether(TABLE[i - 1][0]));
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

        it('gives referral comission', async function() {
          expect(await this.reserveToken.balanceOf(REFERRAL_ADDRESS)).to.be.bignumber.equal(this.sellTax);
        });
      });
    }

    describe(`edge cases`, function() {
      beforeEach(async function() {
        const buyAmount = calculateReserveWithTax('1.0')[0];
        await this.bond.buy(this.token.address, buyAmount, 0, REFERRAL_ADDRESS, { from: alice }); // Buy 10 tokens
        this.buyAmountAfterTax = await this.bond.reserveBalance(this.token.address); // 0.997
        await this.token.approve(this.bond.address, MAX_UINT256, { from: alice });

        this.balance = await this.token.balanceOf(alice); // should be 10
        this.sellTax = this.buyAmountAfterTax.mul(new BN('13')).div(new BN('1000')); // 1.3% sell tax
      });

      it('cannot sell more than user balance', async function () {
        await this.bond.buy(this.token.address, ether('1.00'), 0, REFERRAL_ADDRESS, { from: bob }); // To prevent tokenSupply < tokenAmount (reverting on getBurnRefund)

        await expectRevert(
          this.bond.sell(this.token.address, ether('10').addn(1), 0, REFERRAL_ADDRESS, { from: alice }),
          'VM Exception while processing transaction: revert ERC20: burn amount exceeds balance',
        );

        // Should not revert
        await this.bond.sell(this.token.address, ether('10'), 0, REFERRAL_ADDRESS, { from: alice });
      });

      it('burns referral comission if referral is not set', async function() {
        await this.bond.sell(this.token.address, this.balance, 0, ZERO_ADDRESS, { from: alice }); // Sell all tokens (should return all reserve)

        expect(await this.reserveToken.totalSupply()).to.be.bignumber.equal(
          ether(TOTAL_RESERVE_SUPPLY).sub(this.sellTax) // 1.3% burnt
        );
      });

      it('should revert if minReward is not satisfied', async function() {
        expectRevert(
          this.bond.sell(this.token.address, this.balance, this.buyAmountAfterTax.sub(this.sellTax).addn(1), REFERRAL_ADDRESS, { from: alice }),
          'SLIPPAGE_LIMIT_EXCEEDED'
        );

        // Should not revert
        await this.bond.sell(this.token.address, this.balance, this.buyAmountAfterTax.sub(this.sellTax), REFERRAL_ADDRESS, { from: alice });
      });
    });
  });
});