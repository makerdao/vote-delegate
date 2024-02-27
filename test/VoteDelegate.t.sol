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

import {VoteDelegate, ChiefLike, PollingLike, GemLike} from "src/VoteDelegate.sol";

interface ChiefExtendedLike is ChiefLike {
    function approvals(address) external view returns (uint256);
}

interface GemLikeExtended is GemLike {
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function mint(address, uint256) external;
}

contract VoteDelegateTest is DssTest {
    using stdStorage for StdStorage;

    uint256 constant electionSize = 3;
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);
    bytes byts;

    VoteDelegate proxy;
    GemLikeExtended gov;
    ChiefExtendedLike chief;
    PollingLike polling;

    address delegate = address(111);
    address delegator1 = address(222);
    address delegator2 = address(333);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        chief = ChiefExtendedLike(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
        polling = PollingLike(0xD3A9FE267852281a1e6307a1C37CDfD76d39b133);
        gov = GemLikeExtended(address(chief.GOV()));

        // Give us admin access to mint MKR
        stdstore.target(address(gov)).sig("owner()").checked_write(address(this));

        gov.mint(address(delegate), 100 ether);
        gov.mint(address(delegator1), 10_000 ether);
        gov.mint(address(delegator2), 20_000 ether);

        proxy = new VoteDelegate(address(chief), address(polling), address(delegate));
    }

    function testConstructor() public {
        VoteDelegate v = new VoteDelegate(address(chief), address(polling), address(delegate));
        assertEq(address(v.chief()), address(chief));
        assertEq(address(v.polling()), address(polling));
        assertEq(v.delegate(), delegate);
        assertEq(address(v.gov()), address(chief.GOV()));
        assertEq(gov.allowance(address(v), address(chief)), type(uint256).max);
        assertEq(GemLikeExtended(address(chief.IOU())).allowance(address(v), address(chief)), type(uint256).max);
    }

    function testModifiers() public {
        bytes4[] memory authedMethods = new bytes4[](4);
        authedMethods[0] = bytes4(keccak256("vote(address[])"));
        authedMethods[1] = bytes4(keccak256("vote(bytes32)"));
        authedMethods[2] = bytes4(keccak256("votePoll(uint256,uint256)"));
        authedMethods[3] = bytes4(keccak256("votePoll(uint256[],uint256[])"));

        vm.startPrank(address(0xBEEF));
        checkModifier(address(proxy), "VoteDelegate/sender-not-delegate", authedMethods);
        vm.stopPrank();
    }

    function testProxyLockFree() public {
        uint256 initialMKR = gov.balanceOf(address(chief));

        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);

        assertEq(gov.balanceOf(address(delegate)), 100 ether);

        vm.prank(delegate); proxy.lock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), initialMKR + 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.prank(delegate); proxy.free(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), initialMKR);
        assertEq(proxy.stake(address(delegate)), 0);
    }

    function testDelegatorLockFree() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        vm.prank(delegator1); gov.approve(address(proxy), type(uint256).max);

        vm.prank(delegator1); proxy.lock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 10_000 ether);
        assertEq(proxy.stake(address(delegator1)), 10_000 ether);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);

        vm.prank(delegator1); proxy.free(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(proxy.stake(address(delegator1)), 0);
    }

    function testDelegatorLockFreeFuzz(uint256 wad_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 20_000 ether;
        uint256 currMKR = gov.balanceOf(address(chief));

        vm.prank(delegator2); gov.approve(address(proxy), type(uint256).max);

        uint256 delGovBalance = gov.balanceOf(address(delegator2));

        vm.prank(delegator2); proxy.lock(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance - wad);
        assertEq(gov.balanceOf(address(chief)), currMKR + wad);
        assertEq(proxy.stake(address(delegator2)), wad);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);

        vm.prank(delegator2); proxy.free(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(proxy.stake(address(delegator2)), 0);
    }

    function testDelegateVoting() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);
        vm.prank(delegator1); gov.approve(address(proxy), type(uint256).max);

        vm.prank(delegate); proxy.lock(100 ether);
        vm.prank(delegator1); proxy.lock(10_000 ether);

        assertEq(gov.balanceOf(address(chief)), currMKR + 10_100 ether);

        address[] memory yays = new address[](1);
        yays[0] = c1;
        vm.prank(delegate); proxy.vote(yays);
        assertEq(chief.approvals(c1), 10_100 ether);
        assertEq(chief.approvals(c2), 0 ether);

        address[] memory _yays = new address[](1);
        _yays[0] = c2;
        vm.prank(delegate); proxy.vote(_yays);
        assertEq(chief.approvals(c1), 0 ether);
        assertEq(chief.approvals(c2), 10_100 ether);
    }

    function testDelegatePolling() public {
        // We can't test much as they are pure events
        // but at least we can check it doesn't revert

        vm.prank(delegate); proxy.votePoll(1, 1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory opts = new uint256[](2);
        opts[0] = 1;
        opts[1] = 3;
        vm.prank(delegate); proxy.votePoll(ids, opts);
    }

    function testDelegateVotingFuzz(uint256 wad_seed, uint256 wad2_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 100 ether;
        uint256 wad2 = wad2_seed < 1 ether ?  wad2_seed += 1 ether : wad2_seed % 20_000 ether;
        uint256 currMKR = gov.balanceOf(address(chief));

        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);
        vm.prank(delegator2); gov.approve(address(proxy), type(uint256).max);

        uint256 delGovBalance = gov.balanceOf(address(delegate));
        uint256 del2GovBalance = gov.balanceOf(address(delegator2));

        vm.prank(delegate); proxy.lock(wad);
        vm.prank(delegator2); proxy.lock(wad2);

        assertEq(gov.balanceOf(address(delegate)), delGovBalance - wad);
        assertEq(gov.balanceOf(address(delegator2)), del2GovBalance - wad2);
        assertEq(proxy.stake(address(delegate)), wad);
        assertEq(proxy.stake(address(delegator2)), wad2);
        assertEq(gov.balanceOf(address(chief)), currMKR + wad + wad2);

        address[] memory yays = new address[](1);
        yays[0] = c1;
        vm.prank(delegate); proxy.vote(yays);
        assertEq(chief.approvals(c1), wad + wad2);
        assertEq(chief.approvals(c2), 0 ether);

        address[] memory _yays = new address[](1);
        _yays[0] = c2;
        vm.prank(delegate); proxy.vote(_yays);
        assertEq(chief.approvals(c1), 0 ether);
        assertEq(chief.approvals(c2), wad + wad2);
    }

    function testRevertsDelegateAttemptsSteal() public {
        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);
        vm.prank(delegator1); gov.approve(address(proxy), type(uint256).max);

        vm.prank(delegate); proxy.lock(100 ether);
        vm.prank(delegator1); proxy.lock(10_000 ether);

        // Attempting to steal more MKR than you put in
        vm.expectRevert();
        vm.prank(delegate); proxy.free(101 ether);
    }
}
