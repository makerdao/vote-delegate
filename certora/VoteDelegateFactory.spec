// VoteDelegateFactory.spec

methods {
    // storage variables
    function delegates(address) external returns (address) envfree;
    function created(address) external returns (uint256) envfree;
    // immutables
    function chief() external returns (address) envfree;
    function polling() external returns (address) envfree;
}

definition addrZero() returns address = 0x0000000000000000000000000000000000000000;

// Verify correct storage changes for non reverting create
rule create() {
    env e;

    address voteDelegate = create(e);

    address delegatesSenderAfter = delegates(e.msg.sender);
    mathint createdAfter = created(delegatesSenderAfter);

    assert delegatesSenderAfter != addrZero(), "Assert 1";
    assert delegatesSenderAfter == voteDelegate, "Assert 2";
    assert createdAfter == 1, "Assert 3";
}

// Verify revert rules on create
rule create_revert() {
    env e;

    address delegatesSender = delegates(e.msg.sender);

    create@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = delegatesSender != addrZero();

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}
