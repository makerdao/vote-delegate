pragma solidity ^0.4.24;

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
        bytes4 sig = bytes4(keccak256("breakLink()"));
        return address(voteDelegateFactory).call(sig);
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
        assertEq(voteDelegateFactory.linkRequests(cold), address(0));
        cold.doInitiateLink(hot);
        assertEq(voteDelegateFactory.linkRequests(cold), hot);
    }

    function test_approveLink() public {
        assertEq(voteDelegateFactory.coldMap(cold), address(0));
        assertEq(voteDelegateFactory.hotMap(hot), address(0));
        cold.doInitiateLink(hot);
        hot.doApproveLink(cold);
        assertEq(voteDelegateFactory.coldMap(cold), voteDelegateFactory.hotMap(hot));
        assertEq(voteDelegateFactory.coldMap(cold).cold(), cold);
        assertEq(voteDelegateFactory.hotMap(hot).hot(), hot);
    }

    function test_coldBreakLink() public {
        cold.doInitiateLink(hot);
        hot.doApproveLink(cold);
        assertTrue(voteDelegateFactory.coldMap(cold) != address(0));
        assertTrue(voteDelegateFactory.hotMap(hot) != address(0));
        cold.doBreakLink();
        assertEq(voteDelegateFactory.coldMap(cold), address(0));
        assertEq(voteDelegateFactory.hotMap(hot), address(0));
    }

    function test_hotBreakLink() public {
        cold.doInitiateLink(hot);
        hot.doApproveLink(cold);
        assertTrue(voteDelegateFactory.coldMap(cold) != address(0));
        assertTrue(voteDelegateFactory.hotMap(hot) != address(0));
        hot.doBreakLink();
        assertEq(voteDelegateFactory.coldMap(cold), address(0));
        assertEq(voteDelegateFactory.hotMap(hot), address(0));
    }

    function test_tryBreakLink() public {
        cold.doInitiateLink(hot);
        VoteDelegate voteDelegate = hot.doApproveLink(cold);
        chief.GOV().mint(cold, 1);
        cold.proxyApprove(voteDelegate, chief.GOV());
        cold.proxyLock(voteDelegate, 1);
        assertTrue(!cold.tryBreakLink());

        cold.proxyFree(voteDelegate, 1);
        assertTrue(cold.tryBreakLink());
    }

    function test_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(voteDelegateFactory.coldMap(cold), address(0));
        VoteDelegate voteDelegate = cold.doLinkSelf();
        assertEq(voteDelegateFactory.coldMap(cold), voteDelegate);
        assertEq(voteDelegateFactory.coldMap(cold).cold(), cold);
        assertEq(voteDelegateFactory.hotMap(cold).hot(), cold);
    }

    function testFail_linkSelf() public { // misnomer, transfer uneccessary
        assertEq(voteDelegateFactory.coldMap(cold), address(0));
        cold.doInitiateLink(hot);
        hot.doApproveLink(cold);
        assertEq(voteDelegateFactory.coldMap(cold), hot);
        cold.doLinkSelf();
    }
}
