pragma solidity 0.5.11;

import "ds-test/test.sol";
import "./VoteDelegateFactory.sol";

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
    uint256 constant electionSize = 3;

    VoteDelegateFactory voteDelegateFactory;
    DSToken gov;
    DSToken iou;
    DSChief chief;

    VoteUser delegate;
    VoteUser delegator;

    function setUp() public {
        gov = new DSToken("GOV");

        DSChiefFab fab = new DSChiefFab();
        chief = fab.newChief(gov, electionSize);
        voteDelegateFactory = new VoteDelegateFactory(chief);
        delegator = new VoteUser(voteDelegateFactory);
        delegate  = new VoteUser(voteDelegateFactory);
    }

    function test_constructor() public {
        assertEq(address(voteDelegateFactory.chief()), address(chief));
    }

    function test_create() public {
        assert(!voteDelegateFactory.isDelegate(address(delegate)));
        VoteDelegate voteDelegate = delegate.doCreate();
        assert(voteDelegateFactory.isDelegate(address(delegate)));
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
        assert(voteDelegate.abandoned());
        assert(!voteDelegateFactory.isDelegate(address(delegate)));
        // test that the delegate can now make another VoteDelegate
        voteDelegate = delegate.doCreate();
        assert(voteDelegateFactory.isDelegate(address(delegate)));
        assertEq(
            address(voteDelegateFactory.delegates(address(delegate))),
            address(voteDelegate)
        );
    }
}
