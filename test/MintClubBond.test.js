const { ether, BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256 } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubBond = artifacts.require('MintClubBond');

contract('MintClubBond', function(accounts) {
  const [ deployer, other ] = accounts;

  beforeEach(async function() {
    this.reserveToken = await MintClubToken.new();
    await this.reserveToken.init('Reserve Token', 'RESERVE');
    await this.reserveToken.mint(other, ether('10000000'));

    const tokenImplimentation = await MintClubToken.new();
    this.bond = await MintClubBond.new(this.reserveToken.address, tokenImplimentation.address);
    this.receipt = await this.bond.createToken('New Token', 'NEW', ether('100000'));
    this.token = await MintClubToken.at(this.receipt.logs[0].args.tokenAddress);

    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: other });
  });

  it('should have infinite allowance', async function() {
    expect(await this.reserveToken.allowance(other, this.bond.address, { from: other })).to.be.bignumber.equal(MAX_UINT256);
  });

  /**
   * REF: Price calculation
   * https://docs.google.com/spreadsheets/d/1BbkFrhD3R7waPPw8ZmY5qHrJIe-umJksnsJRsNGRTl4/edit?usp=sharing
   * NOTE: Calculation may be a little bit off because we use an approximate value to save gas (Power.sol)
   *
   * TokenSupply | Price         | Reserve Balance
   * ----------- | ------------- | --------------------
   */
  // const TABLE = [
  //   [ '1'        , '0.000000025' , '0.000000010'        ],
  //   [ '10'       , '0.000000791' , '0.000003162'        ],
  //   [ '100'      , '0.000025000' , '0.001000000'        ],
  //   [ '1000'     , '0.000790569' , '0.316227766'        ],
  //   [ '10000'    , '0.025000000' , '100.000000000'      ],
  //   [ '100000'   , '0.790569415' , '31622.776601684'    ],
  //   [ '1000000'  , '25.000000000', '10000000.000000000' ],
  // ];
  // const TABLE = [
  //   [ '1'        , '0.00000000015' , '0.00000000005'         ],
  //   [ '10'       , '0.00000001500' , '0.00000001355'         ],
  //   [ '100'      , '0.00000150000' , '0.00001355000'         ],
  //   [ '1000'     , '0.00015000000' , '0.01355000000'         ],
  //   [ '10000'    , '0.01500000000' , '13.55000000000'        ],
  //   [ '100000'   , '1.50000000000' , '13550.00000000000'     ],
  //   [ '1000000'  , '150.00000000000', '13550000.00000000000' ],
  // ];
  const TABLE = [
    [ '1'        , '0.00002' , '0.00001'         ],
    [ '10'       , '0.00020' , '0.00100'         ],
    [ '100'      , '0.00200' , '0.10000'         ],
    [ '1000'     , '0.02000' , '10.00000'        ],
    [ '10000'    , '0.20000' , '1000.00000'        ],
    [ '100000'   , '2.00000' , '100000.00000'     ],
    [ '1000000'  , '20.00000', '10000000.00000' ],
  ];

  // it('initial token price', async function() {
  //   expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[0][1]));
  // });

  // it('should have initial reserve balance', async function() {
  //   expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[0][2]));
  // });

  // it('should give 1 token to the creator', async function() {
  //   expect(await this.token.balanceOf(deployer)).to.be.bignumber.equal(ether(TABLE[0][0]));
  // });

  describe('buy', function() {
    for (let i = 1; i < TABLE.length; i++) {
      describe(`up to ${TABLE[i][0]} tokens`, function() {
        beforeEach(async function() {
          // console.log('--------------', TABLE[i][2]-TABLE[0][2]);

          // TODO: Use BN
          await this.bond.buy(this.token.address, ether(TABLE[i][2]), 0, { from: other });
        });

        // TODO: should emit an event

        it('has correct reserve balance', async function() {
          expect(await this.bond.reserveBalance(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][2]));
        });

        it('has correct total supply', async function() {
          expect(await this.bond.tokenSupply(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][0]));
        });

        it('gives user a correct balance', async function() {
          expect(await this.token.balanceOf(other)).to.be.bignumber.equal(ether(TABLE[i][0]));
        });

        it('increases the price per token', async function() {
          expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether(TABLE[i][1]));
        });
      });
    }
  });
});