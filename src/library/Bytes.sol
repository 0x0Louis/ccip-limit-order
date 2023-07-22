// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Bytes {
    error InvalidLength(uint256 expected, uint256 actual);
    error InvalidAddress();

    function toBytes32(bytes memory input) internal pure returns (bytes32 output) {
        if (input.length != 32) revert InvalidLength(32, input.length);

        assembly {
            output := mload(add(input, 0x20))
        }
    }

    function toBytes32(address input) internal pure returns (bytes32 output) {
        assembly {
            output := input
        }
    }

    function toBytes(bytes32 input) internal pure returns (bytes memory output) {
        output = new bytes(32);

        assembly {
            mstore(add(output, 0x20), input)
        }
    }

    function toAddress(bytes32 input) internal pure returns (address output) {
        if (uint256(input) > type(uint160).max) revert InvalidAddress();

        assembly {
            output := input
        }
    }
}
