// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

interface GemLike {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

contract ChiefMock {
    GemLike public GOV;
    bytes32 public lastHashYays;

    function calculateHash(address[] memory yays) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(yays));
    }

    function lock(uint256 wad) external {
        GOV.transferFrom(msg.sender, address(this), wad);
    }

    function free(uint256 wad) external {
        GOV.transfer(msg.sender, wad);
    }

    function vote(address[] memory yays) external returns (bytes32) {
        lastHashYays = calculateHash(yays);
        return lastHashYays;
    }

    function vote(bytes32 slate) external {
        lastHashYays = slate;
    }
}
