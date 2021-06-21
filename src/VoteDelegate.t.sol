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

pragma solidity 0.6.12;

import "ds-test/test.sol";

import {VoteDelegate, PollingLike} from "./VoteDelegate.sol";

interface TokenLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function mint(address, uint256) external;
}

interface ChiefLike {
    function GOV() external view returns (TokenLike);
    function IOU() external view returns (TokenLike);
    function approvals(address) external view returns (uint256);
    function lock(uint256) external;
    function free(uint256) external;
    function vote(address[] calldata) external returns (bytes32);
    function vote(bytes32) external;
}

interface Hevm {
    function warp(uint256) external;
    function roll(uint256) external;
    function store(address,bytes32,bytes32) external;
    function load(address,bytes32) external view returns (bytes32);
}

interface AuthLike {
    function wards(address) external returns (uint256);
}

interface OwnerLike {
    function owner() external returns (address);
}

contract Voter {
    ChiefLike chief;
    PollingLike polling;
    TokenLike gov;
    TokenLike iou;
    VoteDelegate public proxy;

    constructor(ChiefLike chief_, PollingLike polling_) public {
        chief = chief_;
        polling = polling_;
        gov = TokenLike(chief.GOV());
        iou = TokenLike(chief.IOU());
    }

    function expiration() public view returns (uint256) {
        return proxy.expiration();
    }

    function setProxy(VoteDelegate proxy_) public {
        proxy = proxy_;
    }

    function doChiefLock(uint amt) public {
        chief.lock(amt);
    }

    function doChiefFree(uint amt) public {
        chief.free(amt);
    }

    function doTransfer(address guy, uint amt) public {
        gov.transfer(guy, amt);
    }

    function approveGov(address guy) public {
        gov.approve(guy, uint256(-1));
    }

    function approveIou(address guy) public {
        iou.approve(guy, uint256(-1));
    }

    function doProxyLock(uint amt) public {
        proxy.lock(amt);
    }

    function doProxyFree(uint amt) public {
        proxy.free(amt);
    }

    function doProxyFreeAll() public {
        proxy.free(proxy.stake(address(this)));
    }

    function doProxyVote(address[] memory yays) public returns (bytes32 slate) {
        return proxy.vote(yays);
    }

    function doProxyVote(bytes32 slate) public {
        proxy.vote(slate);
    }

    function doProxyVotePoll(uint256 pollId, uint256 optionId) public {
        proxy.votePoll(pollId, optionId);
    }

    function doProxyWithdrawPoll(uint256 pollId) public {
        proxy.withdrawPoll(pollId);
    }

    function doProxyVotePoll(uint256[] calldata pollIds, uint256[] calldata optionIds) public {
        proxy.votePoll(pollIds, optionIds);
    }

    function doProxyWithdrawPoll(uint256[] calldata pollIds) public {
        proxy.withdrawPoll(pollIds);
    }
}

contract NonVoter {
    VoteDelegate public proxy;

    constructor(VoteDelegate proxy_) public {
        proxy = proxy_;
    }

    function doFree(address usr, uint256 wad) public {
        proxy.free(usr, wad);
    }
}

contract VoteDelegateTest is DSTest {
    Hevm hevm;

    uint256 constant electionSize = 3;
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);
    bytes byts;

    VoteDelegate proxy;
    TokenLike gov;
    TokenLike iou;
    ChiefLike chief;
    PollingLike polling;

    Voter delegate;
    Voter delegator1;
    Voter delegator2;
    NonVoter party;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);

        chief = ChiefLike(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
        polling = PollingLike(0xD3A9FE267852281a1e6307a1C37CDfD76d39b133);
        gov = chief.GOV();
        iou = chief.IOU();

        // Give us admin access to mint MKR
        hevm.store(
            address(gov),
            bytes32(uint256(4)),
            bytes32(uint256(address(this)))
        );
        assertEq(OwnerLike(address(gov)).owner(), address(this));

        delegate = new Voter(chief, polling);
        delegator1 = new Voter(chief, polling);
        delegator2 = new Voter(chief, polling);
        gov.mint(address(delegate), 100 ether);
        gov.mint(address(delegator1), 10_000 ether);
        gov.mint(address(delegator2), 20_000 ether);

        proxy = new VoteDelegate(address(chief), address(polling), address(delegate));

        delegate.setProxy(proxy);
        delegator1.setProxy(proxy);
        delegator2.setProxy(proxy);

        party = new NonVoter(proxy);
    }

    function test_proxy_lock_free() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);

        delegate.doProxyLock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Comply with Chief's flash loan protection
        hevm.roll(block.number + 1);
        hevm.warp(block.timestamp + 1);

        delegate.doProxyFree(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegate)), 0);
        assertEq(proxy.stake(address(delegate)), 0);
    }

    function test_3rdParty_lock_free() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);

        delegate.doProxyLock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Comply with Chief's flash loan protection
        hevm.roll(block.number + 1);
        hevm.warp(proxy.expiration() + 1); // Only works after expiration

        party.doFree(address(delegate), 100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegate)), 0);
        assertEq(proxy.stake(address(delegate)), 0);
    }

    function testFail_3rdParty_lock_free() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);

        delegate.doProxyLock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Comply with Chief's flash loan protection
        hevm.roll(block.number + 1);
        hevm.warp(block.timestamp + 1); // Does not work prior to expiration

        party.doFree(address(delegate), 100 ether);
    }

    function test_proxy_lock_free_after_expiration() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);

        delegate.doProxyLock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 100 ether);
        assertEq(proxy.stake(address(delegate)), 100 ether);

        // Flash loan protection
        hevm.roll(block.number + 1);

        // Warp past expiration
        hevm.warp(block.timestamp + 9001 days);

        assertTrue(block.timestamp > delegate.expiration());
        // Always allow freeing after expiration
        delegate.doProxyFree(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegate)), 0);
        assertEq(proxy.stake(address(delegate)), 0);
    }

    function testFail_proxy_lock_after_expiration() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        // Flash loan protection
        hevm.roll(block.number + 1);

        // Warp past expiration
        hevm.warp(block.timestamp + 9001 days);

        // Fail here. Don't allow locking after expiry.
        delegate.doProxyLock(100 ether);
    }

    function test_delegator_lock_free() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 10_000 ether);
        assertEq(iou.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(proxy.stake(address(delegator1)), 10_000 ether);

        // Comply with Chief's flash loan protection
        hevm.roll(block.number + 1);

        delegator1.doProxyFree(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegator1)), 0);
        assertEq(proxy.stake(address(delegator1)), 0);
    }

    function test_delegator_lock_free_fuzz(uint256 wad_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 20_000 ether;
        uint256 currMKR = gov.balanceOf(address(chief));

        delegator2.approveGov(address(proxy));
        delegator2.approveIou(address(proxy));

        uint256 delGovBalance = gov.balanceOf(address(delegator2));

        delegator2.doProxyLock(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance - wad);
        assertEq(gov.balanceOf(address(chief)), currMKR + wad);
        assertEq(iou.balanceOf(address(delegator2)), wad);
        assertEq(proxy.stake(address(delegator2)), wad);

        // Comply with Chief's flash loan protection
        hevm.roll(block.number + 1);

        delegator2.doProxyFree(wad);
        assertEq(gov.balanceOf(address(delegator2)), delGovBalance);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegator2)), 0);
        assertEq(proxy.stake(address(delegator2)), 0);
    }

    function test_delegator_lock_free_after_expiration() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 10_000 ether);
        assertEq(iou.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(proxy.stake(address(delegator1)), 10_000 ether);

        hevm.roll(block.number + 1);

        // Warp past expiration
        hevm.warp(block.timestamp + 9001 days);

        assertTrue(block.timestamp > delegate.expiration());

        // Always allow freeing after expiration.
        delegator1.doProxyFree(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegator1)), 0);
        assertEq(proxy.stake(address(delegator1)), 0);
    }

    function test_delegate_voting() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        assertEq(gov.balanceOf(address(chief)), currMKR + 10_100 ether);

        address[] memory yays = new address[](1);
        yays[0] = c1;
        delegate.doProxyVote(yays);
        assertEq(chief.approvals(c1), 10_100 ether);
        assertEq(chief.approvals(c2), 0 ether);

        address[] memory _yays = new address[](1);
        _yays[0] = c2;
        delegate.doProxyVote(_yays);
        assertEq(chief.approvals(c1), 0 ether);
        assertEq(chief.approvals(c2), 10_100 ether);
    }

    function test_delegate_polling() public {
        // We can't test much as they are pure events
        // but at least we can check it doesn't revert

        delegate.doProxyVotePoll(1, 1);
        delegate.doProxyWithdrawPoll(1);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory opts = new uint256[](2);
        opts[0] = 1;
        opts[1] = 3;
        delegate.doProxyVotePoll(ids, opts);
        delegate.doProxyWithdrawPoll(ids);
    }


    function testFail_delegate_voting_after_expiration() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        assertEq(gov.balanceOf(address(chief)), currMKR + 10_100 ether);

        address[] memory yays = new address[](1);
        yays[0] = c1;

        hevm.roll(block.number + 1);

        // Warp past expiration
        hevm.warp(block.timestamp + 9001 days);

        // Fail here after expiration
        delegate.doProxyVote(yays);
    }

    function test_delegate_voting_fuzz(uint256 wad_seed, uint256 wad2_seed) public {
        uint256 wad = wad_seed < 1 ether ?  wad_seed += 1 ether : wad_seed % 100 ether;
        uint256 wad2 = wad2_seed < 1 ether ?  wad2_seed += 1 ether : wad2_seed % 20_000 ether;
        uint256 currMKR = gov.balanceOf(address(chief));

        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator2.approveGov(address(proxy));
        delegator2.approveIou(address(proxy));

        uint256 delGovBalance = gov.balanceOf(address(delegate));
        uint256 del2GovBalance = gov.balanceOf(address(delegator2));

        delegate.doProxyLock(wad);
        delegator2.doProxyLock(wad2);

        assertEq(gov.balanceOf(address(delegate)), delGovBalance - wad);
        assertEq(gov.balanceOf(address(delegator2)), del2GovBalance - wad2);
        assertEq(iou.balanceOf(address(delegate)), wad);
        assertEq(iou.balanceOf(address(delegator2)), wad2);
        assertEq(proxy.stake(address(delegate)), wad);
        assertEq(proxy.stake(address(delegator2)), wad2);
        assertEq(gov.balanceOf(address(chief)), currMKR + wad + wad2);

        address[] memory yays = new address[](1);
        yays[0] = c1;
        delegate.doProxyVote(yays);
        assertEq(chief.approvals(c1), wad + wad2);
        assertEq(chief.approvals(c2), 0 ether);

        address[] memory _yays = new address[](1);
        _yays[0] = c2;
        delegate.doProxyVote(_yays);
        assertEq(chief.approvals(c1), 0 ether);
        assertEq(chief.approvals(c2), wad + wad2);
    }

    function testFail_delegate_attempts_steal() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        // Attempting to steal more MKR than you put in
        delegate.doProxyFree(101 ether);
    }

    function testFail_attempt_steal_with_ious() public {
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));
        delegator2.approveGov(address(chief));
        delegator2.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);

        // You have enough IOU tokens, but you are still not marked as a delegate
        delegator2.doChiefLock(20_000 ether);

        delegator2.doProxyFree(10_000 ether);
    }

    function testFail_non_delegate_attempts_vote() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        // Delegator2 attempts to vote
        address[] memory yays = new address[](1);
        yays[0] = c1;
        delegator2.doProxyVote(yays);
    }

    function testFail_non_delegate_attempts_polling_vote() public {
        delegator2.doProxyVotePoll(1, 1);
    }

    function testFail_non_delegate_attempts_polling_withdraw() public {
        delegator2.doProxyWithdrawPoll(1);
    }

    function testFail_non_delegate_attempts_polling_vote_multiple() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory opts = new uint256[](2);
        opts[0] = 1;
        opts[1] = 3;
        delegator2.doProxyVotePoll(ids, opts);
    }

    function testFail_non_delegate_attempts_polling_withdraw_multiple() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        delegator2.doProxyWithdrawPoll(ids);
    }
}
