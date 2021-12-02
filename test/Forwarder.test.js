const { ether, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256, ZERO_ADDRESS } = constants;
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

    it('default fund address should be zero address', async function() {
      expect(await this.forwarder.fundAddress()).to.equal(ZERO_ADDRESS);
    });

    it('default fee rate should be 5% (500)', async function() {
      expect(await this.forwarder.feeRate()).to.be.bignumber.equal('500');
    });

    it('admin can change the fund address and fee', async function() {
      await this.forwarder.updateFee(deployer, 3000); // 30%
      expect(await this.forwarder.fundAddress()).to.equal(deployer);
      expect(await this.forwarder.feeRate()).to.be.bignumber.equal('3000');
    });

    it('non admin users should not able to updateFee', async function() {
      await expectRevert(
        this.forwarder.updateFee(deployer, 3000, { from: requester }),
        'Ownable: caller is not the owner'
      );
    });

    it('non admin users should not able to updateTokenOwner', async function() {
      await expectRevert(
        this.forwarder.updateTokenOwner(this.token.address, owner, { from: requester }),
        'Ownable: caller is not the owner'
      );
    });
  });

  describe('request', function() {
    beforeEach(async function() {
      await this.token.approve(this.forwarder.address, MAX_UINT256, { from: requester });
      await this.forwarder.request(this.token.address, ether('100'), { from: requester });
    });

    it("should decrease requester's balance", async function() {
      expect(await this.token.balanceOf(requester)).to.be.bignumber.equal(ether('900'));
    });

    it("should increase contract's balance", async function() {
      expect(await this.token.balanceOf(this.forwarder.address)).to.be.bignumber.equal(ether('100'));
    });

    describe('refund', function() {
      it('should refund to requester', async function() {
        await this.forwarder.refund(this.token.address, ether('50'), { from: requester });
        expect(await this.token.balanceOf(requester)).to.be.bignumber.equal(ether('950'));
        expect(await this.token.balanceOf(this.forwarder.address)).to.be.bignumber.equal(ether('50'));
      });

      it('should revert if amount exceeded', async function() {
        await expectRevert(
          this.forwarder.refund(this.token.address, ether('101'), { from: requester }),
          'AMOUNT_LIMIT_EXCEEDED'
        );
      });

      it('should revert if other account requested refund', async function() {
        await expectRevert(
          this.forwarder.refund(this.token.address, ether('50'), { from: deployer }),
          'AMOUNT_LIMIT_EXCEEDED'
        );
      });
    });

    describe('accept', function() {
      beforeEach(async function() {
        await this.forwarder.updateFee(deployer, 1000); // 10%
        await this.forwarder.updateTokenOwner(this.token.address, owner);
      });

      it('should transfer fund to the owner', async function() {
        await this.forwarder.accept(this.token.address, requester, ether('100'), { from: owner });
        expect(await this.token.balanceOf(owner)).to.be.bignumber.equal(ether('90')); // Took 10% fee
        expect(await this.token.balanceOf(deployer)).to.be.bignumber.equal(ether('10')); // Fee fund
        expect(await this.token.balanceOf(this.forwarder.address)).to.be.bignumber.equal(ether('0'));
      });

      it('should handle 0 fee properly', async function() {
        await this.forwarder.updateFee(deployer, 0);

        await this.forwarder.accept(this.token.address, requester, ether('100'), { from: owner });

        expect(await this.token.balanceOf(owner)).to.be.bignumber.equal(ether('100'));
        expect(await this.token.balanceOf(deployer)).to.be.bignumber.equal(ether('0'));
        expect(await this.token.balanceOf(this.forwarder.address)).to.be.bignumber.equal(ether('0'));
      });

      it('should revert if non-owner called accept function', async function() {
        await expectRevert(
          this.forwarder.accept(this.token.address, requester, ether('100'), { from: deployer }),
          'PERMISSION_DENIED'
        );
      });
    });
  });
});