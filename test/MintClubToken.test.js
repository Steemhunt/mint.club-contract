const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');

contract('MintClubToken', function(accounts) {
  const [ deployer, other ] = accounts;

  const name = 'TestToken';
  const symbol = 'TEST';
  const amount = new BN('5000');

  beforeEach(async function() {
    this.token = await MintClubToken.new();
    await this.token.init(name, symbol);
  });

  it('cannot init twice', async function() {
    await expectRevert(
      this.token.init(name, symbol),
      'CONTRACT_ALREADY_INITIALIZED'
    );
  });

  // NOTICE: Test only covers additional functions (mint, burn, burnFrom)

  describe('minting', function() {
    it('deployer can mint tokens', async function() {
      const receipt = await this.token.mint(other, amount, { from: deployer });
      expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: other, value: amount });

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal(amount);
    });

    it('other accounts cannot mint tokens', async function() {
      await expectRevert(
        this.token.mint(other, amount, { from: other }),
        'Ownable: caller is not the owner',
      );
    });
  });

  describe('ownable', function() {
    it('sets owner properly', async function() {
      expect(await this.token.owner()).to.equal(deployer);
    });

    it('renounceOwnership', async function() {
      const receipt = await this.token.renounceOwnership();
      expectEvent(receipt, 'OwnershipTransferred', { previousOwner: deployer, newOwner: ZERO_ADDRESS });

      expect(await this.token.owner()).to.equal(ZERO_ADDRESS);
    });
  });

  describe('burning', function() {
     beforeEach(async function() {
      await this.token.mint(other, amount, { from: deployer });
      await this.token.approve(deployer, amount, { from: other });
    });

    it('only contract owner can burn their tokens', async function() {
      const receipt = await this.token.burnFrom(other, amount.subn(1), { from: deployer });
      expectEvent(receipt, 'Transfer', { from: other, to: ZERO_ADDRESS, value: amount.subn(1) });

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal('1');
    });

    it("users (not contract owner) cannot burn their own token", async function() {
      await expectRevert(
        this.token.burnFrom(other, amount.subn(1), { from: other }),
        'Ownable: caller is not the owner'
      );

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal(amount);
    });
  });
});