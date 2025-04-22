// SPDX-FileCopyrightText: © 2021 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.21;

interface GemLike {
    function approve(address, uint256) external;
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}

interface ChiefLike {
    function gov() external view returns (GemLike);
    function lock(uint256) external;
    function free(uint256) external;
    function vote(address[] calldata) external returns (bytes32);
    function vote(bytes32) external;
}

interface PollingLike {
    function vote(uint256, uint256) external;
    function vote(uint256[] calldata, uint256[] calldata) external;
}

contract VoteDelegate {
    // --- storage variables ---

    mapping(address => uint256) public stake;

    // --- immutables ---

    address     immutable public delegate;
    GemLike     immutable public gov;
    ChiefLike   immutable public chief;
    PollingLike immutable public polling;

    // --- events ---

    event Lock(address indexed usr, uint256 wad);
    event Free(address indexed usr, uint256 wad);

    // --- constructor ---

    constructor(address chief_, address polling_, address delegate_) {
        chief = ChiefLike(chief_);
        polling = PollingLike(polling_);
        delegate = delegate_;

        gov = ChiefLike(chief_).gov();
        gov.approve(chief_, type(uint256).max);
    }

    // --- modifiers ---

    modifier delegate_auth() {
        require(msg.sender == delegate, "VoteDelegate/sender-not-delegate");
        _;
    }

    // --- gov owner functions

    function lock(uint256 wad) external {
        gov.transferFrom(msg.sender, address(this), wad);
        chief.lock(wad);
        stake[msg.sender] += wad;

        emit Lock(msg.sender, wad);
    }

    function free(uint256 wad) external {
        require(stake[msg.sender] >= wad, "VoteDelegate/insufficient-stake");
        unchecked { stake[msg.sender] -= wad; }
        chief.free(wad);
        gov.transfer(msg.sender, wad);

        emit Free(msg.sender, wad);
    }

    // --- delegate executive voting functions

    function vote(address[] calldata yays) external delegate_auth returns (bytes32 result) {
        result = chief.vote(yays);
    }

    function vote(bytes32 slate) external delegate_auth {
        chief.vote(slate);
    }

    // --- delegate poll voting functions

    function votePoll(uint256 pollId, uint256 optionId) external delegate_auth {
        polling.vote(pollId, optionId);
    }

    function votePoll(uint256[] calldata pollIds, uint256[] calldata optionIds) external delegate_auth {
        polling.vote(pollIds, optionIds);
    }
}
