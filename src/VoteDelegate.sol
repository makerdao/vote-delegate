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

// VoteDelegate - delegate your vote
pragma solidity 0.6.12;

interface TokenLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function pull(address, uint256) external;
    function push(address, uint256) external;
    function transfer(address, uint256) external;
    function mint(address, uint256) external;
}

interface ChiefLike {
    function GOV() external view returns (TokenLike);
    function IOU() external view returns (TokenLike);
    function approvals(address) external view returns (uint256);
    function deposits(address) external view returns (uint256);
    function lock(uint256) external;
    function free(uint256) external;
    function vote(address[] calldata) external returns (bytes32);
    function vote(bytes32) external;
}

contract VoteDelegate {
    mapping(address => uint256) public delegators;
    address public immutable delegate;
    uint256   public immutable expiration;
    TokenLike public immutable gov;
    TokenLike public immutable iou;
    ChiefLike public immutable chief;

    constructor(address _chief, address _delegate, uint256 _expiration) public {
        require(_expiration > block.timestamp && _expiration < block.timestamp + 20 * 365 days, "invalid expiration");
        chief = ChiefLike(_chief);
        delegate = _delegate;
        expiration = _expiration;

        gov = ChiefLike(_chief).GOV();
        iou = ChiefLike(_chief).IOU();

        ChiefLike(_chief).GOV().approve(_chief, uint256(-1));
        ChiefLike(_chief).IOU().approve(_chief, uint256(-1));
    }

    modifier live() {
        require(block.timestamp < expiration, "Delegation contract expired");
        _;
    }

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    modifier delegate_auth() {
        require(msg.sender == delegate, "Sender must be delegate");
        _;
    }

    function lock(uint256 wad) external live {
        delegators[msg.sender] = add(delegators[msg.sender], wad);
        gov.pull(msg.sender, wad);
        chief.lock(wad);
        iou.push(msg.sender, wad);
    }

    function free(uint256 wad) external {
        delegators[msg.sender] = sub(delegators[msg.sender], wad);
        iou.pull(msg.sender, wad);
        chief.free(wad);
        gov.push(msg.sender, wad);
    }

    function vote(address[] memory yays) external delegate_auth live returns (bytes32) {
        return chief.vote(yays);
    }

    function vote(bytes32 slate) external delegate_auth live {
        chief.vote(slate);
    }
}
