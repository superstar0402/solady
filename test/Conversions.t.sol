// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Conversions} from "../src/Conversions.sol";
import "forge-std/console.sol";

contract ConversionsTest is Test {
    Conversions public c;

    function setUp() public {
        c = new Conversions();
    }

    function testS() public {
        string memory result = c.decodeString();
        console.log(result);
    }

    function testSetBool() public {
        uint16 result = c.setBool();
        console.log(result);
    }

    function testPrime() public {
        require(c.isPrime(1));
        require(c.isPrime(2));
        require(!c.isPrime(4));
        require(c.isPrime(5));
        require(c.isPrime(7));
        require(c.isPrime(11));
        require(!c.isPrime(15));
    }

    function testMax() public {
        require(c.max(11, 22) == 22);
    }

    function testSlot() public {
        (uint256 slot, uint256 offset) = c.getSlot();
        bytes32 value = c.readbySlot(0);
        console.log(offset);
        emit log_bytes32(value);
    }

    function testReadX() public {
        uint256 value = c.readX();
        console.log(value);
    }
}
