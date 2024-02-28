// SPDX-FileCopyrightText: © 2021 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later

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

import "dss-test/DssTest.sol";

import "src/VoteDelegateFactory.sol";

contract VoteDelegateFactoryTest is DssTest {
    VoteDelegateFactory factory;
    address chief;
    address polling;

    event CreateVoteDelegate(address indexed usr, address indexed delegate);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        chief = 0x0a3f6849f78076aefaDf113F5BED87720274dDC0;
        polling = 0xD3A9FE267852281a1e6307a1C37CDfD76d39b133;

        factory = new VoteDelegateFactory(address(chief), address(polling));
    }

    function testConstructor() public {
        assertEq(address(factory.chief()), address(chief));
        assertEq(address(factory.polling()), address(polling));
    }

    function testCreate() public {
        address proxy = factory.getAddress(address(1));
        assertEq(factory.created(proxy), 0);
        assertEq(factory.isDelegate(address(1)), 0);
        vm.expectEmit(true, true, true, true);
        emit CreateVoteDelegate(address(1), proxy);
        vm.prank(address(1)); address retAddr = factory.create();
        assertEq(retAddr, proxy);
        assertEq(factory.created(proxy), 1);
        assertEq(factory.isDelegate(address(1)), 1);
        vm.expectRevert();
        vm.prank(address(1)); factory.create();
    }
}
