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

pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import "src/VoteDelegateFactory.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

contract VoteDelegateFactoryTest is DssTest {
    VoteDelegateFactory factory;
    address chief;
    address polling;

    ChainlogLike constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    event CreateVoteDelegate(address indexed usr, address indexed voteDelegate);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        chief = chainlog.getAddress("MCD_ADM");
        polling = 0xD3A9FE267852281a1e6307a1C37CDfD76d39b133;

        factory = new VoteDelegateFactory(address(chief), address(polling));
    }

    function testConstructor() public view {
        assertEq(address(factory.chief()), address(chief));
        assertEq(address(factory.polling()), address(polling));
    }

    function testCreate() public {
        address proxy = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

        assertEq(factory.created(proxy), 0);
        assertEq(factory.isDelegate(address(1)), false);
        assertEq(factory.delegates(address(1)), address(0));
        vm.expectEmit(true, true, true, true);
        emit CreateVoteDelegate(address(1), proxy);
        vm.prank(address(1)); address retAddr = factory.create();
        assertEq(retAddr, proxy);
        assertEq(factory.created(proxy), 1);
        assertEq(factory.isDelegate(address(1)), true);
        assertEq(factory.delegates(address(1)), proxy);
        vm.expectRevert("VoteDelegateFactory/sender-is-already-delegate");
        vm.prank(address(1)); factory.create();
    }
}
