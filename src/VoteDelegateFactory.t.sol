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
