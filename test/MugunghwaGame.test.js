const { ether, constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { MAX_UINT256, ZERO_ADDRESS } = constants;
const { expect } = require('chai');

const MintClubToken = artifacts.require('MintClubToken');
const MugunghwaGame = artifacts.require('MugunghwaGame');

contract('MugunghwaGame', function(accounts) {
  const [ deployer, player1, player2, player3 ] = accounts;

  beforeEach(async function() {
    this.token = await MintClubToken.new();
    await this.token.init('Doge Ground', 'DOGG');
    await this.token.mint(player1, ether('100'));
    await this.token.mint(player2, ether('200'));
    await this.token.mint(player3, ether('300'));

    this.game = await MugunghwaGame.new(this.token.address);
  });

  describe('admin features', function() {
    it('default owner should be deployer', async function() {
      expect(await this.token.owner()).to.equal(deployer);
      expect(await this.game.owner()).to.equal(deployer);
    });
  });
});