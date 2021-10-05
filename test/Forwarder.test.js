const { ether, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { ZERO_ADDRESS } = constants;
const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const Forwarder = artifacts.require('Forwarder');

contract('Forwarder', function(accounts) {
  const [ deployer, requester, owner ] = accounts;

  beforeEach(async function() {
    this.token = await MintClubToken.new();
    await this.token.init('Elon Musk', 'elonmusk');
    await this.token.mint(requester, ether('1000'));

    this.forwarder = await Forwarder.new();
  });

  describe('admin features', function() {
    it('default owner should be zero address', async function() {
      expect(await this.forwarder.tokenOwner(this.token.address)).to.equal(ZERO_ADDRESS);
    });

    it('admin can change the owner of tokens', async function() {
      await this.forwarder.updateTokenOwner(this.token.address, owner);
      expect(await this.forwarder.tokenOwner(this.token.address)).to.equal(owner);
    });

    // TODO: updateFee
  });

  // TODO: Request
  // TODO: Refund
  // TODO: Accept
});