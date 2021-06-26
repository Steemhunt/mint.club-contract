const { ether, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;

const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MintClubFactoryMock = artifacts.require('MintClubFactoryMock');

contract('MintClubFactory', function(accounts) {
  const [ deployer, other ] = accounts;

  beforeEach(async function() {
    const tokenImplimentation = await MintClubToken.new();
    this.factory = await MintClubFactoryMock.new(tokenImplimentation.address);
    this.receipt = await this.factory.createToken('New Token', 'NEW', ether('100.0'));
    this.token = await MintClubToken.at(this.receipt.logs[1].args.tokenAddress);
  });

  describe('creation', function() {
    it('factory can create tokens', async function() {
      const name = await this.token.name();
      const symbol = await this.token.symbol();
      const totalSupply = await this.token.totalSupply();
      const maxTokenSupply = await this.factory.maxSupply(this.token.address);

      expect(name).to.equal('New Token');
      expect(symbol).to.equal('NEW');
      expect(totalSupply).to.be.bignumber.equal('0');
      expectEvent(this.receipt, 'TokenCreated', { tokenAddress: this.token.address, name: name, symbol: symbol, maxTokenSupply: maxTokenSupply });
    });

    it('sets owner of the token as factory', async function() {
      expect(await this.token.owner()).to.equal(this.factory.address);
    });

    it('returns boolean on exists() call', async function() {
      expect(await this.factory.exists(this.token.address)).to.equal(true);
      expect(await this.factory.exists(ZERO_ADDRESS)).to.equal(false);
    });

    it('stores maxSupply', async function() {
      expect(await this.factory.maxSupply(this.token.address)).to.be.bignumber.equal(ether('100'));

      const receipt2 = await this.factory.createToken('New Token 2', 'NEW2', ether('500'));
      expect(await this.factory.maxSupply(receipt2.logs[1].args.tokenAddress)).to.be.bignumber.equal(ether('500'));
    });

    it('canot set maxSupply over MAX_SUPPLY_LIMIT', async function() {
      await expectRevert(
        this.factory.createToken('New Token 2', 'NEW2', ether('1000000').addn(1)),
        'MAX_SUPPLY_LIMIT_EXCEEDED',
      );
    });

    it('increases token count', async function() {
      expect(await this.factory.tokenCount()).to.be.bignumber.equal('1');
      await this.factory.createToken('New Token 2', 'NEW2', ether('500'));
      expect(await this.factory.tokenCount()).to.be.bignumber.equal('2');
    });

    it('stores token address', async function() {
      expect(await this.factory.tokens(0)).to.equal(this.token.address);
    });

    it('stores token parameters', async function() {
      expect(await this.factory.maxSupply(this.token.address)).to.be.bignumber.equal(ether('100'));
    });
  });
});