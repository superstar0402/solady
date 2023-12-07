// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract V2Factory {
    function factoryFeeTo() external view returns (address) {
        return address(this);
    }
}
