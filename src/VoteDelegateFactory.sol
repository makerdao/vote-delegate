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

pragma solidity ^0.8.16;

import {VoteDelegate} from "src/VoteDelegate.sol";

contract VoteDelegateFactory {
    // --- storage variables ---

    mapping(address => uint256) public created;

    // --- immutables ---

    address immutable public chief;
    address immutable public polling;

    // --- constructor ---

    constructor(address _chief, address _polling) {
        chief = _chief;
        polling = _polling;
    }

    function getAddress(address usr) public view returns (address delegate) {
        uint256 salt = uint256(keccak256(abi.encode(usr)));
        bytes32 codeHash = keccak256(abi.encodePacked(type(VoteDelegate).creationCode, abi.encode(chief, polling, usr)));
        delegate = address(uint160(uint256(
            keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt, codeHash)
            )
        )));
    }

    function isDelegate(address usr) external view returns (uint256 ok) {
        ok = created[getAddress(usr)];
    }

    function create() external returns (address delegate) {
        delegate = address(new VoteDelegate{salt: keccak256(abi.encode(msg.sender))}(chief, polling, msg.sender));
        created[delegate] = 1;
    }
}
