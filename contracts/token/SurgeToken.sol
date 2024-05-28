// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title SurgeToken Contract
contract SurgeToken is Ownable, ERC20, Pausable {
    using SafeMath for uint256;

    bool private initialized;

    // for black list
    mapping(address => bool) public blackAccountMap;
    mapping(address => bool) public whiteAccountMap;
    event UpdateBlackAccount(address addr, bool isBlackAccount);
    event UpdateWhiteAccount(address addr, bool isWhiteAccount);

    /**
     * CONSTRUCTOR
     *
     * @dev Initialize the Token
     */
    constructor() ERC20("SURGE", "SURGE") {}

    function initialize(address _owner) external {
        require(!initialized, "initialize: Already initialized!");

        _transferOwnership(_owner);
        _mint(_owner, 1000000000 * 10 ** 18);
        _pause();
        initialized = true;
    }

    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function updateBlackAccount(
        address account,
        bool isBlack
    ) external onlyOwner {
        require(blackAccountMap[account] != isBlack, "account has been set");
        blackAccountMap[account] = isBlack;
        emit UpdateBlackAccount(account, isBlack);
    }

    function updateWhiteAccount(
        address account,
        bool isWhite
    ) external onlyOwner {
        require(whiteAccountMap[account] != isWhite, "account has been set");
        whiteAccountMap[account] = isWhite;
        emit UpdateWhiteAccount(account, isWhite);
    }

    /**
     * @dev Transfer tokens with fee
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256s the amount of tokens to be transferred
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (paused()) {
            require(whiteAccountMap[from], "can't transfer");
        }
        require(!blackAccountMap[from], "can't transfer");
        super._transfer(from, to, value);
    }

    function name() public view virtual override returns (string memory) {
        return "SURGETOKEN";
    }

    function symbol() public view virtual override returns (string memory) {
        return "SURGE";
    }
}
