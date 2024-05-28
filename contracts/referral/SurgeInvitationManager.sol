// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interface/ISurgeInvitation.sol";

contract SurgeInvitationManager is Ownable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bool private initialized;
    ISurgeInvitation public surgeInvitation;

    bytes32 constant OPERATOR_ROLE_ADMIN = keccak256("OPERATOR_ROLE_ADMIN");

    // 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bool public isOpenCreate;
    mapping(address => bool) public isWhitelists;

    // base 1_000_000_000_000_000_000
    // discountRate; // for self [vip levrl]
    // commissionRate; //for inviter
    mapping(uint256 => uint256) discountRate;
    mapping(uint256 => uint256) commissionRate;

    mapping(address => mapping(address => uint256)) public commissions;
    mapping(address => bool) public isCreated;

    event SettleCommissions(
        address indexed inviteeAddress,
        address indexed inviterAddress,
        uint256 amount,
        address pledgeToken
    );
    event ClaimCommission(
        bytes32 indexed inviteCode,
        address indexed inviter,
        address pledgeToken,
        uint256 amount
    );
    event SetConfig(
        uint256[] levels,
        uint256[] discountRates,
        uint256[] commissionRates
    );

    function initialize(
        address _owner,
        ISurgeInvitation _surgeInvitation
    ) external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(_owner);

        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE_ADMIN);
        _setupRole(OPERATOR_ROLE_ADMIN, _owner);

        surgeInvitation = _surgeInvitation;
        initialized = true;
    }

    function setInviteConfig(
        uint256[] calldata _levels,
        uint256[] calldata _discountRates,
        uint256[] calldata _commissionRates
    ) external onlyOwner {
        for (uint256 i = 0; i < _levels.length; i++) {
            uint256 _level = _levels[i];
            uint256 _discountRate = _discountRates[i];
            uint256 _commissionRate = _commissionRates[i];
            discountRate[_level] = _discountRate;
            commissionRate[_level] = _commissionRate;
        }
        emit SetConfig(_levels, _discountRates, _commissionRates);
    }

    function addWhitelists(address[] calldata _addresses) external onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            isWhitelists[_addresses[i]] = true;
        }
    }

    function setOpenCreate(bool _isOpenCreate) external onlyOwner {
        isOpenCreate = _isOpenCreate;
    }

    function createInviteCode(
        string memory inviterCode,
        string memory registrationCode
    ) external nonReentrant returns (string memory) {
        if (!isOpenCreate) {
            require(isWhitelists[msg.sender], "not whitelists");
        }
        require(!isCreated[msg.sender], "has created");
        isCreated[msg.sender] = true;

        return
            surgeInvitation.createInviteCode(
                msg.sender,
                inviterCode,
                registrationCode
            );
    }

    function getDiscountRate(uint256 level) external view returns (uint256) {
        return discountRate[level];
    }

    function getCommissionRate(uint256 level) external view returns (uint256) {
        return commissionRate[level];
    }

    function settleCommission(
        address _inviteeAddress,
        uint256 _amount,
        address _pledgeToken
    ) external onlyRole(OPERATOR_ROLE) {
        address inviterAddress_ = surgeInvitation.getInviterAddressByInvitee(
            _inviteeAddress
        );

        IERC20(_pledgeToken).safeTransfer(inviterAddress_, _amount);
        emit SettleCommissions(
            _inviteeAddress,
            inviterAddress_,
            _amount,
            _pledgeToken
        );

        commissions[inviterAddress_][_pledgeToken] += _amount;
    }
}
