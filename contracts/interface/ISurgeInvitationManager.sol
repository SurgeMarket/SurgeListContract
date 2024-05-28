// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ISurgeInvitationManager {
    function settleCommission(
        address _inviteeAddress,
        uint256 _amount,
        address _pledgeToken
    ) external;

    // base 1_000_000_000_000_000_000
    function getDiscountRate(uint256 level) external view returns (uint256);

    function getCommissionRate(uint256 level) external view returns (uint256);
}
