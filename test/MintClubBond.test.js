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

    await this.token.approve(this.bond.address, MAX_UINT256, { from: deployer });
  });

  it('should have infinite allowance', async function() {

  }

  it('initial token price is zero', async function() {
    // TODO: Fix after proper INITIAL_SUPPLY, INITIAL_RESERVE are set
    expect(await this.bond.currentPrice(this.token.address)).to.be.bignumber.equal('3');
  });

  describe('buy', function() {
    it('sends reward tokens to the user', async function() {
      // ∫ (x^2) dx (0->30) = 9000
      await this.bond.buy(this.token.address, ether('8.66'), 2);
      // TODO: Event
      expect(await this.token.balanceOf(deployer)).to.be.bignumber.equal(ether('2.00'));
    });
  });
});