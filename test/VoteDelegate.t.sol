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

import {VoteDelegate, ChiefLike, PollingLike, GemLike} from "src/VoteDelegate.sol";

interface ChiefExtendedLike is ChiefLike {
    function approvals(address) external view returns (uint256);
}

interface GemLikeExtended is GemLike {
    function allowance(address, address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function mint(address, uint256) external;
}

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

contract VoteDelegateTest is DssTest {
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);

    VoteDelegate proxy;
    GemLikeExtended gov;
    ChiefExtendedLike chief;
    PollingLike polling;

    address delegate = address(111);
    address delegator1 = address(222);
    address delegator2 = address(333);

    ChainlogLike constant chainlog = ChainlogLike(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    event Lock(address indexed usr, uint256 wad);
    event Free(address indexed usr, uint256 wad);
    event Voted(address indexed voter, uint256 indexed pollId, uint256 indexed optionId);

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        chief = ChiefExtendedLike(chainlog.getAddress("MCD_ADM"));
        polling = PollingLike(0xD3A9FE267852281a1e6307a1C37CDfD76d39b133);
        gov = GemLikeExtended(address(chief.gov()));

        deal(address(gov), address(delegate), 100 ether, true);
        deal(address(gov), address(delegator1), 10_000 ether, true);
        deal(address(gov), address(delegator2), 20_000 ether, true);

        proxy = new VoteDelegate(address(chief), address(polling), address(delegate));
    }

    function testConstructor() public view {
        assertEq(address(proxy.chief()), address(chief));
        assertEq(address(proxy.polling()), address(polling));
        assertEq(proxy.delegate(), delegate);
        assertEq(address(proxy.gov()), address(chief.gov()));
        assertEq(gov.allowance(address(proxy), address(chief)), type(uint256).max);
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
        uint256 initialGov = gov.balanceOf(address(chief));

        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);

        assertEq(gov.balanceOf(address(delegate)), 100 ether);

        vm.expectEmit(true, true, true, true);
        emit Lock(delegate, 100 ether);
        vm.prank(delegate); proxy.lock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), initialGov + 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit Free(delegate, 100 ether);
        vm.prank(delegate); proxy.free(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), initialGov);
        assertEq(proxy.stake(address(delegate)), 0);
    }

    function testDelegatorLockFree() public {
        uint256 initialGov = gov.balanceOf(address(chief));

        vm.prank(delegator1); gov.approve(address(proxy), type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit Lock(delegator1, 10_000 ether);
        vm.prank(delegator1); proxy.lock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), initialGov + 10_000 ether);
        assertEq(proxy.stake(address(delegator1)), 10_000 ether);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit Free(delegator1, 10_000 ether);
        vm.prank(delegator1); proxy.free(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), initialGov);
        assertEq(proxy.stake(address(delegator1)), 0);
    }

    function testDelegatorLockFreeFuzz(uint256 wad_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 20_000 ether;
        uint256 initialGov = gov.balanceOf(address(chief));

        vm.prank(delegator2); gov.approve(address(proxy), type(uint256).max);

        uint256 delGovBalance = gov.balanceOf(address(delegator2));

        vm.expectEmit(true, true, true, true);
        emit Lock(delegator2, wad);
        vm.prank(delegator2); proxy.lock(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance - wad);
        assertEq(gov.balanceOf(address(chief)), initialGov + wad);
        assertEq(proxy.stake(address(delegator2)), wad);

        // Comply with Chief's flash loan protection
        vm.roll(block.number + 1);

        vm.expectEmit(true, true, true, true);
        emit Free(delegator2, wad);
        vm.prank(delegator2); proxy.free(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance);
        assertEq(gov.balanceOf(address(chief)), initialGov);
        assertEq(proxy.stake(address(delegator2)), 0);
    }

    function testDelegateVoting() public {
        uint256 initialGov = gov.balanceOf(address(chief));

        vm.prank(delegate); gov.approve(address(proxy), type(uint256).max);
        vm.prank(delegator1); gov.approve(address(proxy), type(uint256).max);

        vm.prank(delegate); proxy.lock(100 ether);
        vm.prank(delegator1); proxy.lock(10_000 ether);

        assertEq(gov.balanceOf(address(chief)), initialGov + 10_100 ether);

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
        // but at least we can check it doesn't revert and events are emitted

        vm.expectEmit(true, true, true, true);
        emit Voted(address(proxy), 1, 1);
        vm.prank(delegate); proxy.votePoll(1, 1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory opts = new uint256[](2);
        opts[0] = 1;
        opts[1] = 3;
        vm.expectEmit(true, true, true, true);
        emit Voted(address(proxy), 1, 1);
        vm.prank(delegate); proxy.votePoll(ids, opts);
    }

    function testDelegateVotingFuzz(uint256 wad_seed, uint256 wad2_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 100 ether;
        uint256 wad2 = wad2_seed < 1 ether ?  wad2_seed += 1 ether : wad2_seed % 20_000 ether;
        uint256 initialGov = gov.balanceOf(address(chief));

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
        assertEq(gov.balanceOf(address(chief)), initialGov + wad + wad2);

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

        // Attempting to take more gov tokens than assigned in the stake mapping (having a greater total)
        vm.expectRevert("VoteDelegate/insufficient-stake");
        vm.prank(delegate); proxy.free(100 ether + 1);
    }
}
