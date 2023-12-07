// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Conversions {
    uint128 public x = 4;
    uint128 public y = 5;

    function decodeString() public pure returns (string memory) {
        bytes32 word;
        string memory input = "my name is Mehdi and I love sport sport sport sport sport";

        assembly {
            word := mload(add(input, 32))
        }
        return string(abi.encode(word));
    }

    function setBool() external pure returns (uint16) {
        uint16 x;

        assembly {
            x := 4
        }

        return x;
    }

    function isPrime(uint256 n) external pure returns (bool result) {
        result = true;

        assembly {
            let halfNumber := add(div(n, 2), 1)
            for { let i := 2 } lt(i, halfNumber) { i := add(i, 1) } {
                if iszero(mod(n, i)) {
                    result := 0
                    break
                }
            }
        }
    }

    function max(uint256 x, uint256 y) external pure returns (uint256 maxium) {
        assembly {
            if lt(x, y) { maxium := y }
            if iszero(lt(x, y)) { maxium := x }
        }
    }

    function getSlot() external pure returns (uint256 slot, uint256 offset) {
        assembly {
            slot := y.slot
            offset := y.offset
        }
    }

    function readbySlot(uint256 slot) external view returns (bytes32 result) {
        assembly {
            result := sload(slot)
        }
    }

    function readX() external view returns (uint256 _x) {
        assembly {
            let value := sload(x.slot)
            let shifted := shr(mul(x.offset, 8), value)

            _x := and(0xffffffff, shifted)
        }
    }
}
