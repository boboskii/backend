// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// 来自https://github.com/pear-protocol/pear-public-sale/blob/main/src/PublicSale.sol

import '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract PublicSale is Ownable {

    error SaleIsPaused();

    event SaleStarted(uint40 saleStartEpoch);
    event SalePaused(uint40 salePauseEpoch);

    event BuyOrder(address indexed buyer, uint256 amount, uint256 tokenAmount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    // TOKEN PRICE
    // Only accept USDC for payment
    IERC20 private immutable usdcToken;
    IERC20 private immutable Token;
    uint256 private pricePerToken = 0.01 * 1e6;
    bool private isPaused = true;


    constructor(address usdcToken_, address Token_, address owner_) Ownable(owner_){
        usdcToken = IERC20(usdcToken_);
        Token = IERC20(Token_);
    }

    /**
     * @dev Modifier that checks if the sale has started.
     */
    modifier isNotPaused() {
        if (isPaused) revert SaleIsPaused();
        _;
    }

    /**
     * @dev Function that allows users to preview the amount of tokens they will get.
     * @param usdcAmount_ The amount of USDC to spend.
     */
    function previewBuyTokens(uint256 usdcAmount_) public view returns (uint256) {
        // example calculation: 1 * 1e6 USDC = 100 * 1e18 tokens
        return (usdcAmount_ * 1e18) / pricePerToken;
    }

    function tokensForSale() public view returns (uint256) {
        return Token.balanceOf(address(this));
    }

    /**
     * @dev Function that allows users to buy tokens.
     * @param usdcAmount_ The amount of USDC to spend.
     */
    function buyTokens(uint256 usdcAmount_) external isNotPaused {
        uint256 tokenAmount = previewBuyTokens(usdcAmount_);
        require(tokenAmount <= Token.balanceOf(address(this)), 'Exceeds sale allocation');
        require(usdcToken.allowance(msg.sender, address(this)) >= usdcAmount_, 'allowance not enough');
        bool success = usdcToken.transferFrom(msg.sender, address(this), usdcAmount_);
        require(success, 'Transfer failed');
        Token.transfer(msg.sender, tokenAmount);
        emit BuyOrder(msg.sender, usdcAmount_, tokenAmount);
    }

    /**
     * @dev Function that allows the owner to withdraw the USDC balance.
     */
    function withdrawUsdc() external onlyOwner {
        uint256 balance = usdcToken.balanceOf(address(this));
        bool success = usdcToken.transfer(owner(), balance);
        require(success,'Transfer failed');
        emit FundsWithdrawn(owner(), balance);
    }

    function setPricePerToken(uint256 price_) external onlyOwner {
        pricePerToken = price_;
    }

    function stopSale() external onlyOwner {
        isPaused = true;
        uint256 balance = Token.balanceOf(address(this));
        bool success = Token.transfer(owner(), balance);
        require(success,'Transfer failed');
        emit SalePaused(uint40(block.timestamp));
    }

    /**
     * @dev Function that allows the owner toggle pause state.
     */
    function togglePause() external onlyOwner {
        isPaused = !isPaused;
        if (isPaused) {
            emit SalePaused(uint40(block.timestamp));
        } else {
            emit SaleStarted(uint40(block.timestamp));
        }
    }

}
