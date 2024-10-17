// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

contract PollingMock {
    uint256 public lastPollId;
    uint256 public lastOptionId;

    bytes32 public lastHashPollIds;
    bytes32 public lastHashOptionIds;

    function calculateHash(uint256[] memory v) public returns (bytes32) {
        return keccak256(abi.encodePacked(v));
    }

    function vote(uint256 pollId, uint256 optionId) external {
        lastPollId = pollId;
        lastOptionId = optionId;
    }

    function vote(uint256[] calldata pollIds, uint256[] calldata optionIds) external {
        lastHashPollIds = calculateHash(pollIds);
        lastHashOptionIds = calculateHash(optionIds);
    }
}
