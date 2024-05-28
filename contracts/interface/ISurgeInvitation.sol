// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISurgeInvitation {
    struct Inviter {
        bytes32 code;
        address owner;
        bytes32 inviterCode;
        uint256 inviteeCount;
    }

    function inviterCodeIsCreated(
        string memory _inviterCode
    ) external view returns (bool isCreated);

    function createInviteCode(
        address _sender,
        string memory _inviterCode,
        string memory _registrationCode
    ) external returns (string memory);

    function createInvitation(
        address _inviteeAddress,
        string memory _inviterCode
    ) external returns (bool);

    function getInviteCodes(
        address _inviter
    ) external returns (bytes32[] memory);

    function getInviterAddressByInvitee(
        address _invitee
    ) external view returns (address);

    function getInviterByInvitee(
        address _invitee
    ) external view returns (Inviter memory);

    function getInviterCodeByInvitee(
        address _invitee
    ) external view returns (bytes32 inviterCode);

    // inviter code => address
    function getInviterAddressByCode(
        string memory _inviteCode
    ) external returns (address);

    function getInviterAddressByCodeBytes(
        bytes32 _inviteCodeByte32
    ) external returns (address);
}
