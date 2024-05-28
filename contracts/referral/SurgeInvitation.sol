// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interface/ISurgeInvitation.sol";
import "../library/InviteCodeFilter.sol";

contract SurgeInvitation is
    Ownable,
    AccessControl,
    ReentrancyGuard,
    ISurgeInvitation
{
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bool private initialized;
    // uint256 private inviteId;

    bytes32 constant OPERATOR_ROLE_ADMIN = keccak256("OPERATOR_ROLE_ADMIN");

    // 0xd709fced5bd6320bcb02c381e898bd184d4327ad6db363bc93710243e70ec5af
    bytes32 constant CREATECODE_ROLE = keccak256("CREATECODE_ROLE");

    // 0xe48c4df2b5024f5dc85c4ffb45c0f15ff7d46867e14f384a86659b0f41841b9d
    bytes32 constant POOLCALL_ROLE = keccak256("POOLCALL_ROLE");

    // address => inviteCodes
    mapping(address => EnumerableSet.Bytes32Set) private inviteCodeSets;

    // code => Inviter
    mapping(bytes32 => Inviter) inviteCode2Inviters;

    mapping(address => bytes32) inviterCodeByInvitee;

    bytes32 constant defultCode = "surge";

    Inviter defultInviter;

    // inviter => inviterCodes
    // todo
    // mapping(address => string) inviterCodes;

    event ChangeInviter(address newInviter);
    event CreateInviteCode(
        address indexed sender,
        bytes32 registrationCode,
        bytes32 inviterCode
    );

    event CreateInvitation(address invitee, bytes32 inviteCode);

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function initialize(address _owner, address _defultInviter) external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(_owner);
        _setRoleAdmin(CREATECODE_ROLE, OPERATOR_ROLE_ADMIN);
        _setRoleAdmin(POOLCALL_ROLE, OPERATOR_ROLE_ADMIN);
        _setupRole(OPERATOR_ROLE_ADMIN, _owner);

        defultInviter = Inviter({
            code: defultCode,
            owner: _defultInviter,
            inviterCode: defultCode,
            inviteeCount: 0
        });

        inviteCode2Inviters[defultCode] = defultInviter;
        initialized = true;
    }

    function createInviteCode(
        address _sender,
        string memory _inviterCode,
        string memory _registrationCode
    ) external onlyRole(CREATECODE_ROLE) returns (string memory) {
        // check if the registration code has been used
        // filter name + condition checks
        bytes32 registrationCode_ = InviteCodeFilter.codeFilter(
            _registrationCode
        );

        Inviter memory codeInvite_ = inviteCode2Inviters[registrationCode_];
        require(
            codeInvite_.owner == address(0),
            "SurgeInvitation: The invite code has been used"
        );

        bytes32 inviterCode_ = _code2Bytes32(_inviterCode);

        // get the inviter by the inviter code
        Inviter storage _inviter = inviteCode2Inviters[inviterCode_];
        if (_inviter.owner == address(0)) {
            _inviter = defultInviter;
        }
        _inviter.inviteeCount++;

        // set the inviter code to the sender
        inviteCode2Inviters[registrationCode_] = Inviter({
            code: registrationCode_,
            owner: _sender,
            inviterCode: _inviter.code,
            inviteeCount: 0
        });

        inviterCodeByInvitee[_sender] = _inviter.code;

        inviteCodeSets[_sender].add(registrationCode_);

        emit CreateInviteCode(_sender, registrationCode_, inviterCode_);
        return _registrationCode;
    }

    function _code2Bytes32(
        string memory _inviteCode
    ) internal pure returns (bytes32 inviteCode_) {
        bytes memory tempCode = bytes(_inviteCode);
        if (tempCode.length >= 0) {
            assembly {
                inviteCode_ := mload(add(tempCode, 32))
            }
        }
    }

    function createInvitation(
        address _inviteeAddress,
        string memory _inviterCode
    ) external onlyRole(POOLCALL_ROLE) nonReentrant returns (bool) {
        if (inviterCodeByInvitee[_inviteeAddress] == bytes32(0)) {
            // get the inviter by the inviter code
            Inviter storage _inviter = inviteCode2Inviters[
                _code2Bytes32(_inviterCode)
            ];
            if (_inviter.owner == address(0)) {
                _inviter = defultInviter;
            }
            _inviter.inviteeCount++;

            inviterCodeByInvitee[_inviteeAddress] = _inviter.code;

            emit CreateInvitation(_inviteeAddress, _inviter.code);
            return true;
        }
        return false;
    }

    function getInviterByCode(
        string memory _inviteCode
    ) external view returns (Inviter memory _inviter) {
        _inviter = inviteCode2Inviters[_code2Bytes32(_inviteCode)];
        if (_inviter.owner == address(0)) {
            _inviter = defultInviter;
        }
    }

    function getInviterAddressByCode(
        string memory _inviteCode
    ) external view returns (address) {
        Inviter memory _inviter = inviteCode2Inviters[
            _code2Bytes32(_inviteCode)
        ];
        if (_inviter.owner == address(0)) {
            return defultInviter.owner;
        }
        return _inviter.owner;
    }

    function getInviterAddressByCodeBytes(
        bytes32 _inviteCodeByte32
    ) external view returns (address) {
        Inviter memory _inviter = inviteCode2Inviters[_inviteCodeByte32];
        if (_inviter.owner == address(0)) {
            return defultInviter.owner;
        }
        return _inviter.owner;
    }

    function getInviteCodes(
        address _inviter
    ) external view returns (bytes32[] memory) {
        return inviteCodeSets[_inviter].values();
    }

    function getInviterAddressByInvitee(
        address _invitee
    ) external view returns (address) {
        bytes32 inviterCode = inviterCodeByInvitee[_invitee];
        Inviter memory _inviter = inviteCode2Inviters[inviterCode];
        if (_inviter.owner == address(0)) {
            return defultInviter.owner;
        }
        return _inviter.owner;
    }

    function getInviterByInvitee(
        address _invitee
    ) external view returns (Inviter memory) {
        bytes32 inviterCode = inviterCodeByInvitee[_invitee];
        return inviteCode2Inviters[inviterCode];
    }

    function getInviterCodeByInvitee(
        address _invitee
    ) external view returns (bytes32 inviterCode) {
        inviterCode = inviterCodeByInvitee[_invitee];
    }

    function inviterCodeIsCreated(
        string memory _inviterCode
    ) external view returns (bool isCreated) {
        Inviter storage _inviter = inviteCode2Inviters[
            _code2Bytes32(_inviterCode)
        ];
        if (_inviter.owner == address(0)) {
            isCreated = false;
        } else {
            isCreated = true;
        }
    }

    function getDefultInviter() external view returns (Inviter memory) {
        return defultInviter;
    }

    function changeDefultInviter(address _newInviter) external onlyOwner {
        defultInviter.owner = _newInviter;
        emit ChangeInviter(_newInviter);
    }

    function name() public view virtual returns (string memory) {
        return "InviteCode";
    }

    function symbol() public view virtual returns (string memory) {
        return "IC";
    }
}
