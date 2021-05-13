pragma solidity 0.6.12;

import "ds-test/test.sol";

import "./VoteDelegate.sol";

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
    TokenLike gov;
    TokenLike iou;
    VoteDelegate public proxy;

    constructor(ChiefLike chief_, TokenLike gov_, TokenLike iou_) public {
        chief = chief_;
        gov = gov_;
        iou = iou_;
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
        proxy.free(proxy.delegators(address(this)));
    }

    function doProxyVote(address[] memory yays) public returns (bytes32 slate) {
        return proxy.vote(yays);
    }

    function doProxyVote(bytes32 slate) public {
        proxy.vote(slate);
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

    Voter delegate;
    Voter delegator1;
    Voter delegator2;

    function setUp() public {
        hevm = Hevm(HEVM_ADDRESS);

        chief = ChiefLike(0x0a3f6849f78076aefaDf113F5BED87720274dDC0);
        gov = chief.GOV();
        iou = chief.IOU();

        // Give us admin access to mint MKR
        hevm.store(
            address(gov),
            bytes32(uint256(4)),
            bytes32(uint256(address(this)))
        );
        assertEq(OwnerLike(address(gov)).owner(), address(this));

        delegate = new Voter(chief, gov, iou);
        delegator1 = new Voter(chief, gov, iou);
        delegator2 = new Voter(chief, gov, iou);
        gov.mint(address(delegate), 100 ether);
        gov.mint(address(delegator1), 10_000 ether);
        gov.mint(address(delegator2), 20_000 ether);

        proxy = new VoteDelegate(address(chief), address(delegate));

        delegate.setProxy(proxy);
        delegator1.setProxy(proxy);
        delegator2.setProxy(proxy);
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
        assertEq(proxy.delegators(address(delegate)), 100 ether);

        // Flash loan protection
        hevm.roll(block.number + 1);

        delegate.doProxyFree(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegate)), 0);
        assertEq(proxy.delegators(address(delegate)), 0);
   }

   function test_delegator_lock_free() public {
        uint256 currMKR = gov.balanceOf(address(chief));

        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), currMKR + 10_000 ether);
        assertEq(iou.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(proxy.delegators(address(delegator1)), 10_000 ether);

        hevm.roll(block.number + 1);

        delegator1.doProxyFree(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), currMKR);
        assertEq(iou.balanceOf(address(delegator1)), 0);
        assertEq(proxy.delegators(address(delegator1)), 0);
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
}
