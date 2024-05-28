// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Test is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public iValue;
    bytes32 public root;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        // Add your authorization logic here
        // For example, you can check if the new implementation is a trusted address
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function setI(uint256 _i) external returns (uint256) {
        iValue = _i;
        return iValue;
    }

    function getI() external view returns (uint256) {
        return iValue;
    }

    function setRoot(bytes32 _root) external {
        root = _root;
    }

    function verify(bytes32[] memory proof) public view returns (bool) {
        // bytes32 computedHash = leaf;
        bytes32 computedHash = keccak256(abi.encodePacked(msg.sender));
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}
