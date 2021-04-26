const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');

contract('MintClubToken', function (accounts) {
  const [ deployer, other ] = accounts;

  const name = 'TestToken';
  const symbol = 'TEST';
  const amount = new BN('5000');

  const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const MINTER_ROLE = web3.utils.soliditySha3('MINTER_ROLE');
  const PAUSER_ROLE = web3.utils.soliditySha3('PAUSER_ROLE');

  beforeEach(async function () {
    this.token = await MintClubToken.new();
    await this.token.init(name, symbol);
  });

  describe('minting', function () {
    it('deployer can mint tokens', async function () {
      const receipt = await this.token.mint(other, amount, { from: deployer });
      expectEvent(receipt, 'Transfer', { from: ZERO_ADDRESS, to: other, value: amount });

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal(amount);
    });

    it('other accounts cannot mint tokens', async function () {
      await expectRevert(
        this.token.mint(other, amount, { from: other }),
        'PERMISSION_DENIED',
      );
    });
  });

  describe('burning', function () {
    it('holders can burn their tokens', async function () {
      await this.token.mint(other, amount, { from: deployer });

      const receipt = await this.token.burn(amount.subn(1), { from: other });
      expectEvent(receipt, 'Transfer', { from: other, to: ZERO_ADDRESS, value: amount.subn(1) });

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal('1');
    });

    it("users cannot burn others' tokens", async function () {
      await this.token.mint(other, amount, { from: deployer });

      expectRevert(
        this.token.burnFrom(other, amount.subn(1), { from: deployer }),
        'ERC20: burn amount exceeds allowance'
      );

      expect(await this.token.balanceOf(other)).to.be.bignumber.equal(amount);
    });
  });
});