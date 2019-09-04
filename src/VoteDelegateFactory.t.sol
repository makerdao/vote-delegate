pragma solidity >=0.4.24;

import "ds-test/test.sol";
import "./VoteDelegateFactory.sol";

contract VoteUser {
    DSChief chief;
    VoteDelegateFactory voteDelegateFactory;

    constructor(VoteDelegateFactory voteDelegateFactory_) public {
        voteDelegateFactory = voteDelegateFactory_;
    }

    function doInitiateLink(address hot) public {
        voteDelegateFactory.initiateLink(hot);
    }

    function doApproveLink(address cold) public returns (VoteDelegate) {
        return voteDelegateFactory.approveLink(cold);
    }

    function doLinkSelf() public returns (VoteDelegate) {
        return voteDelegateFactory.linkSelf();
    }

    function doBreakLink() public {
        voteDelegateFactory.breakLink();
    }

    function tryBreakLink() public returns (bool) {
        bytes memory sig = abi.encodeWithSignature("breakLink()");
        (bool ok, bytes memory ret) = address(voteDelegateFactory).call(sig); ret;
        return ok;
    }

    function proxyApprove(address _proxy, DSToken _token) public {
        _token.approve(_proxy);
    }

    function proxyLock(VoteDelegate _proxy, uint amount) public {
        _proxy.lock(amount);
    }

    function proxyFree(VoteDelegate _proxy, uint amount) public {
        _proxy.free(amount);
    }
}


contract VoteDelegateFactoryTest is DSTest {
    uint256 constant electionSize = 3;

    VoteDelegateFactory voteDelegateFactory;
    DSToken gov;
    DSToken iou;
    DSChief chief;

    VoteUser cold;
    VoteUser hot;

    function setUp() public {
        gov = new DSToken("GOV");

        DSChiefFab fab = new DSChiefFab();
        chief = fab.newChief(gov, electionSize);
        voteDelegateFactory = new VoteDelegateFactory(chief);
        cold = new VoteUser(voteDelegateFactory);
        hot  = new VoteUser(voteDelegateFactory);
    }

    function test_initiateLink() public {
        assertEq(voteDelegateFactory.linkRequests(address(cold)), address(0));
        cold.doInitiateLink(address(hot));
        assertEq(voteDelegateFactory.linkRequests(address(cold)), address(hot));
    }

    function test_approveLink() public {
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteDelegateFactory.hotMap(address(hot))), address(0));
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(voteDelegateFactory.hotMap(address(hot))));
        assertEq(address(voteDelegateFactory.coldMap(address(cold)).cold()), address(cold));
        assertEq(address(voteDelegateFactory.hotMap(address(hot)).hot()), address(hot));
    }

    function test_coldBreakLink() public {
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertTrue(address(voteDelegateFactory.coldMap(address(cold))) != address(0));
        assertTrue(address(voteDelegateFactory.hotMap(address(hot))) != address(0));
        cold.doBreakLink();
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteDelegateFactory.hotMap(address(hot))), address(0));
    }

    function test_hotBreakLink() public {
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertTrue(address(voteDelegateFactory.coldMap(address(cold))) != address(0));
        assertTrue(address(voteDelegateFactory.hotMap(address(hot))) != address(0));
        hot.doBreakLink();
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(0));
        assertEq(address(voteDelegateFactory.hotMap(address(hot))), address(0));
    }

    function test_tryBreakLink() public {
        cold.doInitiateLink(address(hot));
        VoteDelegate voteDelegate = hot.doApproveLink(address(cold));
        chief.GOV().mint(address(cold), 1);
        cold.proxyApprove(address(voteDelegate), chief.GOV());
        cold.proxyLock(voteDelegate, 1);
        assertTrue(!cold.tryBreakLink());

        cold.proxyFree(voteDelegate, 1);
        assertTrue(cold.tryBreakLink());
    }

    function test_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(0));
        VoteDelegate voteDelegate = cold.doLinkSelf();
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(voteDelegate));
        assertEq(address(voteDelegateFactory.coldMap(address(cold)).cold()), address(cold));
        assertEq(address(voteDelegateFactory.hotMap(address(cold)).hot()), address(cold));
    }

    function testFail_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(0));
        cold.doInitiateLink(address(hot));
        hot.doApproveLink(address(cold));
        assertEq(address(voteDelegateFactory.coldMap(address(cold))), address(hot));
        cold.doLinkSelf();
    }
}
