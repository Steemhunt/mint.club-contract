const { ether, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256 } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubBond = artifacts.require('MintClubBond');

contract('MintClubBond', function(accounts) {
  const [ deployer, other ] = accounts;

  beforeEach(async function() {
    this.reserveToken = await MintClubToken.new();
    await this.reserveToken.init('Reserve Token', 'RESERVE');
    await this.reserveToken.mint(deployer, ether('1000'));

    const tokenImplimentation = await MintClubToken.new();
    this.bond = await MintClubBond.new(this.reserveToken.address, tokenImplimentation.address);
    this.receipt = await this.bond.createToken('New Token', 'NEW', ether('100000'));
    this.token = await MintClubToken.at(this.receipt.logs[0].args.tokenAddress);

    await this.reserveToken.approve(this.bond.address, MAX_UINT256, { from: deployer });
  });

  it('should have infinite allowance', async function() {
    expect(await this.reserveToken.allowance(deployer, this.bond.address, { from: deployer })).to.be.bignumber.equal(MAX_UINT256);
  });

  it('initial token price is zero', async function() {
    // TODO: Fix after proper INITIAL_SUPPLY, INITIAL_RESERVE are set
    expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether('0.003000003000003'));
  });

  // REF: Price calculation
  // https://docs.google.com/spreadsheets/d/1BbkFrhD3R7waPPw8ZmY5qHrJIe-umJksnsJRsNGRTl4/edit?usp=sharing

  // TODO: Make a helper function to validate the calculations

  describe('buy', function() {
    it('sends reward tokens to the user', async function() {
      // ∫ (x^2) dx (0->30) = 9000
      await this.bond.buy(this.token.address, ether('7.999'), 0);
      // TODO: Event
      expect(await this.token.balanceOf(deployer)).to.be.bignumber.equal(ether('19'));
      expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal(ether('1.20'));
    });
  });
});