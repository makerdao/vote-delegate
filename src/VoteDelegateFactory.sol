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

import {VoteDelegate} from "src/VoteDelegate.sol";

contract VoteDelegateFactory {
    // --- storage variables ---

    mapping(address usr => address voteDelegate)     public delegates;
    mapping(address voteDelegate => uint256 created) public created;

    // --- immutables ---

    address immutable public chief;
    address immutable public polling;

    // --- events ---

    event CreateVoteDelegate(address indexed usr, address indexed voteDelegate);

    // --- constructor ---

    constructor(address _chief, address _polling) {
        chief = _chief;
        polling = _polling;
    }

    function isDelegate(address usr) public view returns (bool ok) {
        ok = delegates[usr] != address(0);
    }

    function create() external returns (address voteDelegate) {
        require(!isDelegate(msg.sender), "VoteDelegateFactory/sender-is-already-delegate");

        voteDelegate = address(new VoteDelegate(chief, polling, msg.sender));
        delegates[msg.sender] = voteDelegate;
        created[voteDelegate] = 1;

        emit CreateVoteDelegate(msg.sender, voteDelegate);
    }
}
