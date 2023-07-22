// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Bytes {
    error InvalidLength(uint256 expected, uint256 actual);

    function toBytes32(bytes memory input) internal pure returns (bytes32 output) {
        if (input.length != 32) revert InvalidLength(32, input.length);

        assembly {
            output := mload(add(input, 0x20))
        }
    }
}
