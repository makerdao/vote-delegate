// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation

// This program is free software: you can redistribute it and/or modify             // it under the terms of the GNU Affero General Public License as published by
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

pragma solidity 0.6.12;

import "ds-test/test.sol";

import "./VoteDelegateFactory.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external view returns (bytes32);
}

contract VoteUser {
    VoteDelegateFactory voteDelegateFactory;

    constructor(VoteDelegateFactory voteDelegateFactory_) public {
        voteDelegateFactory = voteDelegateFactory_;
    }

    function doCreate() public returns (VoteDelegate) {
        return voteDelegateFactory.create();
    }

    function doDestroy() public {
        voteDelegateFactory.destroy();
    }
}


contract VoteDelegateFactoryTest is DSTest {
    Hevm hevm;

    uint256 constant electionSize = 3;

    VoteDelegateFactory voteDelegateFactory;
    TokenLike gov;
    TokenLike iou;
    ChiefLike chief;

    VoteUser delegate;
    VoteUser delegator;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);

        chief = ChiefLike(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
        gov = chief.GOV();
        iou = chief.IOU();

        voteDelegateFactory = new VoteDelegateFactory(address(chief));
        delegator = new VoteUser(voteDelegateFactory);
        delegate  = new VoteUser(voteDelegateFactory);
    }

    function test_constructor() public {
        assertEq(address(voteDelegateFactory.chief()), address(chief));
    }

    function test_create() public {
        assertTrue(!voteDelegateFactory.isDelegate(address(delegate)));
        VoteDelegate voteDelegate = delegate.doCreate();
        assertTrue(voteDelegateFactory.isDelegate(address(delegate)));
        assertEq(
            address(voteDelegateFactory.delegates(address(delegate))),
            address(voteDelegate)
        );
    }

    function testFail_create() public {
        delegate.doCreate();
        delegate.doCreate();
    }

    function testFail_destroy() public {
        delegator.doDestroy();
    }

    function test_destroy() public {
        VoteDelegate voteDelegate = delegate.doCreate();
        delegate.doDestroy();
        assertTrue(!voteDelegateFactory.isDelegate(address(delegate)));
        // test that the delegate can now make another VoteDelegate
        voteDelegate = delegate.doCreate();
        assertTrue(voteDelegateFactory.isDelegate(address(delegate)));
        assertEq(
            address(voteDelegateFactory.delegates(address(delegate))),
            address(voteDelegate)
        );
    }
}
