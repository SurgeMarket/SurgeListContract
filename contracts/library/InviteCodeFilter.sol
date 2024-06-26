// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

library InviteCodeFilter {
    /**
     * @dev filters code strings
     * -converts uppercase to lower case.
     * -makes sure it does not start/end with a space
     * -makes sure it does not contain multiple spaces in a row
     * -cannot be only numbers
     * -cannot start with 0x
     * -restricts characters to A-Z, a-z, 0-9, and space.
     * @return reprocessed string in bytes32 format
     */
    function codeFilter(string memory _input) internal pure returns (bytes32) {
        bytes memory _temp = bytes(_input);
        uint256 _length = _temp.length;

        //sorry limited to 32 characters
        require(
            _length <= 32 && _length > 0,
            "invite code must be between 1 and 32 characters"
        );
        // make sure first two characters are not 0x
        if (_temp[0] == 0x30) {
            require(_temp[1] != 0x78, "invite code cannot start with 0x");
            require(_temp[1] != 0x58, "invite code cannot start with 0X");
        }

        // create a bool to track if we have a non number character
        bool _hasNonNumber;

        // convert & check
        for (uint256 i = 0; i < _length; i++) {
            // if its uppercase A-Z
            if (_temp[i] > 0x40 && _temp[i] < 0x5b) {
                // convert to lower case a-z
                _temp[i] = bytes1(uint8(_temp[i]) + 32);

                // we have a non number
                if (_hasNonNumber == false) _hasNonNumber = true;
            } else {
                require(
                    // OR lowercase a-z
                    (_temp[i] > 0x60 && _temp[i] < 0x7b) ||
                        // or 0-9
                        (_temp[i] > 0x2f && _temp[i] < 0x3a),
                    "invite code cannot contains invalid characters"
                );

                // see if we have a character other than a number
                if (
                    _hasNonNumber == false &&
                    (_temp[i] < 0x30 || _temp[i] > 0x39)
                ) _hasNonNumber = true;
            }
        }

        require(_hasNonNumber == true, "invite code cannot be only numbers");

        bytes32 _ret;
        assembly {
            _ret := mload(add(_temp, 32))
        }
        return (_ret);
    }
}
