const { BN, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubFactory = artifacts.require('MintClubFactory');

contract('MintClubFactory', function (accounts) {
  const [ deployer, other ] = accounts;

  beforeEach(async function () {
    this.factory = await MintClubFactory.new();
    this.receipt = await this.factory.createToken('New Token', 'NEW');
    this.token = await MintClubToken.at(this.receipt.logs[0].args.tokenAddress);
  });

  it('factory can mint tokens', async function () {
    expectEvent(this.receipt, 'TokenCreated', { tokenAddress: this.token.address });
    expect(await this.token.name()).to.equal('New Token');
    expect(await this.token.symbol()).to.equal('NEW');
  });

  describe('permissions', function() {
    const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
    const MINTER_ROLE = web3.utils.soliditySha3('MINTER_ROLE');
    const PAUSER_ROLE = web3.utils.soliditySha3('PAUSER_ROLE');

    it('factory has the default admin role', async function () {
      expect(await this.token.getRoleMemberCount(DEFAULT_ADMIN_ROLE)).to.be.bignumber.equal('1');
      expect(await this.token.getRoleMember(DEFAULT_ADMIN_ROLE, 0)).to.equal(this.factory.address);
    });

    it('factory has the minter role', async function () {
      expect(await this.token.getRoleMemberCount(MINTER_ROLE)).to.be.bignumber.equal('1');
      expect(await this.token.getRoleMember(MINTER_ROLE, 0)).to.equal(this.factory.address);
    });

    it('factory has the pauser role', async function () {
      expect(await this.token.getRoleMemberCount(PAUSER_ROLE)).to.be.bignumber.equal('1');
      expect(await this.token.getRoleMember(PAUSER_ROLE, 0)).to.equal(this.factory.address);
    });

    it('minter and pauser role admin is the default admin', async function () {
      expect(await this.token.getRoleAdmin(MINTER_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
      expect(await this.token.getRoleAdmin(PAUSER_ROLE)).to.equal(DEFAULT_ADMIN_ROLE);
    });
  });
});