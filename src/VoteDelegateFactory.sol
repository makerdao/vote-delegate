// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation

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

// VoteDelegateFactory - create and keep record of delegats
pragma solidity >=0.6.12;

import "./VoteDelegate.sol";

contract VoteDelegateFactory {
    address public immutable chief;
    address public immutable polling;
    mapping(address => address[]) public delegates;

    event CreateVoteDelegate(
        address indexed delegate,
        address indexed voteDelegate
    );

    constructor(address _chief, address _polling) public {
        chief = _chief;
        polling = _polling;
    }

    function isDelegate(address guy) public view returns (bool) {
        return delegates[guy].length != 0;
    }

    function create(
        bool _isDelegatorBypassEnabled,
        uint8 _emergencyUnlockBurnPercent,
        uint256 _lockupPeriod
    ) external returns (address voteDelegate) {
        bool duplicate = isDuplicate(msg.sender, _isDelegatorBypassEnabled, _emergencyUnlockBurnPercent, _lockupPeriod);
        require(duplicate, "VoteDelegateFactory/sender-is-already-delegate");

        voteDelegate = address(new VoteDelegate(
            chief, 
            polling, 
            msg.sender, 
            _isDelegatorBypassEnabled, 
            _emergencyUnlockBurnPercent, 
            _lockupPeriod
        ));
        delegates[msg.sender].push(voteDelegate);
        emit CreateVoteDelegate(msg.sender, voteDelegate);
    }

    function isDuplicate(
        address guy, 
        bool _isDelegatorBypassEnabled,
        uint8 _emergencyUnlockBurnPercent,
        uint256 _lockupPeriod
    ) public view returns (bool) {
        if (!isDelegate(guy)) {
            return true;
        }
        address[] storage delegateContracts = delegates[guy];
        for (uint i = 0; i < delegateContracts.length; ++i) {
            VoteDelegate instance = VoteDelegate(delegateContracts[i]);
            bool paramsEq = instance.emergencyUnlockBurnPercent() == _emergencyUnlockBurnPercent &&
                    instance.isDelegatorBypassEnabled() == _isDelegatorBypassEnabled &&
                    instance.lockupPeriod() == _lockupPeriod;
            if (!paramsEq) {
                return true;
            }
        }
        return false;
    }
}
