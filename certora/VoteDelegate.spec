// VoteDelegate.spec

using GovMock as gov;
using IouMock as iou;
using ChiefMock as chief;
using PollingMock as polling;

methods {
    // storage variables
    function stake(address) external returns (uint256) envfree;
    function hatchTrigger() external returns (uint256) envfree;
    // immutables
    function delegate() external returns (address) envfree;
    function gov() external returns (address) envfree;
    function chief() external returns (address) envfree;
    function polling() external returns (address) envfree;
    // constants
    function HATCH_SIZE() external returns (uint256) envfree;
    function HATCH_COOLDOWN() external returns (uint256) envfree;
    //
    function gov.allowance(address,address) external returns (uint256) envfree;
    function gov.balanceOf(address) external returns (uint256) envfree;
    function gov.totalSupply() external returns (uint256) envfree;
    function iou.allowance(address,address) external returns (uint256) envfree;
    function iou.totalSupply() external returns (uint256) envfree;
    function iou.balanceOf(address) external returns (uint256) envfree;
    function chief.lastHashYays() external returns (bytes32) envfree;
    function chief.calculateHash(address[]) external returns (bytes32) envfree;
    function polling.lastPollId() external returns (uint256) envfree;
    function polling.lastOptionId() external returns (uint256) envfree;
    function polling.lastHashPollIds() external returns (bytes32) envfree;
    function polling.lastHashOptionIds() external returns (bytes32) envfree;
    function polling.calculateHash(uint256[]) external returns (bytes32) envfree;
}

// Verify that each storage layout is only modified in the corresponding functions
rule storageAffected(method f) filtered { f -> !f.isView } {
    env e;

    address anyAddr;

    mathint stakeBefore = stake(anyAddr);
    mathint hatchTriggerBefore = hatchTrigger();

    calldataarg args;
    f(e, args);

    mathint stakeAfter = stake(anyAddr);
    mathint hatchTriggerAfter = hatchTrigger();

    assert stakeAfter != stakeBefore => f.selector == sig:lock(uint256).selector || f.selector == sig:free(uint256).selector, "Assert 1";
    assert hatchTriggerAfter != hatchTriggerBefore => f.selector == sig:reserveHatch().selector, "Assert 2";
}

// Verify correct storage changes for non reverting lock
rule lock(uint256 wad) {
    env e;

    require e.msg.sender != currentContract && e.msg.sender != chief;

    mathint stakeSenderBefore = stake(e.msg.sender);
    mathint govBalanceofSenderBefore = gov.balanceOf(e.msg.sender);
    mathint govBalanceofVoteDelegateBefore = gov.balanceOf(currentContract);
    mathint govBalanceOfChiefBefore = gov.balanceOf(chief);
    require gov.totalSupply() >= govBalanceofSenderBefore + govBalanceofVoteDelegateBefore + govBalanceOfChiefBefore;
    mathint iouTotalSupplyBefore = iou.totalSupply();
    mathint iouBalanceOfVoteDelegateBefore = iou.balanceOf(currentContract);
    require iouTotalSupplyBefore >= iouBalanceOfVoteDelegateBefore;

    lock(e, wad);

    mathint stakeSenderAfter = stake(e.msg.sender);
    mathint govBalanceOfSenderAfter = gov.balanceOf(e.msg.sender);
    mathint govBalanceOfVoteDelegateAfter = gov.balanceOf(currentContract);
    mathint govBalanceOfChiefAfter = gov.balanceOf(chief);
    mathint iouTotalSupplyAfter = iou.totalSupply();
    mathint iouBalanceOfVoteDelegateAfter = iou.balanceOf(currentContract);

    assert stakeSenderAfter == stakeSenderBefore + wad, "Assert 1";
    assert govBalanceOfSenderAfter == govBalanceofSenderBefore - wad, "Assert 2";
    assert govBalanceOfVoteDelegateAfter == govBalanceofVoteDelegateBefore, "Assert 3";
    assert govBalanceOfChiefAfter == govBalanceOfChiefBefore + wad, "Assert 4";
    assert iouTotalSupplyAfter == iouTotalSupplyBefore + wad, "Assert 5";
    assert iouBalanceOfVoteDelegateAfter == iouBalanceOfVoteDelegateBefore + wad, "Assert 6";
}

// Verify revert rules on lock
rule lock_revert(uint256 wad) {
    env e;
    
    mathint stakeSender = stake(e.msg.sender);
    mathint govTotalSupply = gov.totalSupply();
    mathint govBalanceofSender = gov.balanceOf(e.msg.sender);
    mathint govBalanceofVoteDelegate = gov.balanceOf(currentContract);
    mathint govBalanceOfChief = gov.balanceOf(chief);
    mathint iouTotalSupply = iou.totalSupply();
    mathint iouBalanceOfVoteDelegate = iou.balanceOf(currentContract);
    // Assumptions from tokens regular behavior
    require govTotalSupply >= govBalanceofSender + govBalanceofVoteDelegate + govBalanceOfChief;
    require iouTotalSupply >= iouBalanceOfVoteDelegate;
    // Assumption from VoteDelegate constructor
    require gov.allowance(currentContract, chief) == max_uint256;
    // Assumption from Chief functionality
    require iouTotalSupply == govBalanceOfChief;
    // Assumption from user settings
    require govBalanceofSender >= wad;
    require gov.allowance(e.msg.sender, currentContract) >= wad;

    mathint hatchTrigger = hatchTrigger();
    mathint hatchSize = HATCH_SIZE();

    lock@withrevert(e, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.block.number != hatchTrigger && e.block.number <= hatchTrigger + hatchSize;
    bool revert3 = stakeSender + wad > max_uint256;

    assert lastReverted <=> revert1 || revert2 || revert3, "Revert rules failed";
}

// Verify correct storage changes for non reverting free
rule free(uint256 wad) {
    env e;

    require e.msg.sender != currentContract && e.msg.sender != chief;

    mathint stakeSenderBefore = stake(e.msg.sender);
    mathint govBalanceofSenderBefore = gov.balanceOf(e.msg.sender);
    mathint govBalanceofVoteDelegateBefore = gov.balanceOf(currentContract);
    mathint govBalanceOfChiefBefore = gov.balanceOf(chief);
    require gov.totalSupply() >= govBalanceofSenderBefore + govBalanceofVoteDelegateBefore + govBalanceOfChiefBefore;
    mathint iouTotalSupplyBefore = iou.totalSupply();
    mathint iouBalanceOfVoteDelegateBefore = iou.balanceOf(currentContract);
    require iouTotalSupplyBefore >= iouBalanceOfVoteDelegateBefore;

    free(e, wad);

    mathint stakeSenderAfter = stake(e.msg.sender);
    mathint govBalanceOfSenderAfter = gov.balanceOf(e.msg.sender);
    mathint govBalanceOfVoteDelegateAfter = gov.balanceOf(currentContract);
    mathint govBalanceOfChiefAfter = gov.balanceOf(chief);
    mathint iouTotalSupplyAfter = iou.totalSupply();
    mathint iouBalanceOfVoteDelegateAfter = iou.balanceOf(currentContract);

    assert stakeSenderAfter == stakeSenderBefore - wad, "Assert 1";
    assert govBalanceOfSenderAfter == govBalanceofSenderBefore + wad, "Assert 2";
    assert govBalanceOfVoteDelegateAfter == govBalanceofVoteDelegateBefore, "Assert 3";
    assert govBalanceOfChiefAfter == govBalanceOfChiefBefore - wad, "Assert 4";
    assert iouTotalSupplyAfter == iouTotalSupplyBefore - wad, "Assert 5";
    assert iouBalanceOfVoteDelegateAfter == iouBalanceOfVoteDelegateBefore - wad, "Assert 6";
}

// Verify revert rules on free
rule free_revert(uint256 wad) {
    env e;
    
    mathint stakeSender = stake(e.msg.sender);
    mathint govTotalSupply = gov.totalSupply();
    mathint govBalanceofSender = gov.balanceOf(e.msg.sender);
    mathint govBalanceofVoteDelegate = gov.balanceOf(currentContract);
    mathint govBalanceOfChief = gov.balanceOf(chief);
    mathint iouTotalSupply = iou.totalSupply();
    mathint iouBalanceOfVoteDelegate = iou.balanceOf(currentContract);
    // Assumptions from tokens regular behavior
    require govTotalSupply >= govBalanceofSender + govBalanceofVoteDelegate + govBalanceOfChief;
    require iouTotalSupply >= iouBalanceOfVoteDelegate;
    // Assumption from VoteDelegate constructor
    require iou.allowance(currentContract, chief) == max_uint256;
    // Assumption from chief/voteDelegate functionality // TODO: check in invariant
    require govBalanceOfChief >= stakeSender;
    require iouBalanceOfVoteDelegate == stakeSender;

    free@withrevert(e, wad);

    bool revert1 = e.msg.value > 0;
    bool revert2 = stakeSender < to_mathint(wad);

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting reserveHatch
rule reserveHatch() {
    env e;

    reserveHatch(e);

    mathint hatchTriggerAfter = hatchTrigger();

    assert hatchTriggerAfter == e.block.number, "Assert 1";
}

// Verify revert rules on reserveHatch
rule reserveHatch_revert() {
    env e;

    mathint hatchTrigger = hatchTrigger();
    mathint hatchSize = HATCH_SIZE();
    mathint hatchCooldown = HATCH_COOLDOWN();

    reserveHatch@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.block.number < hatchTrigger + hatchSize + hatchCooldown;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting vote
rule voteYays(address[] yays) {
    env e;

    bytes32 hash = chief.calculateHash(yays);

    bytes32 ret = vote(e, yays);

    bytes32 lastHashYaysAfter = chief.lastHashYays();

    assert lastHashYaysAfter == hash, "Assert 1";
    assert ret == hash, "Assert 2";
}

// Verify revert rules on vote
rule voteYays_revert(address[] yays) {
    env e;

    address delegate = delegate();

    vote@withrevert(e, yays);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != delegate;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting vote
rule voteSlate(bytes32 slate) {
    env e;

    vote(e, slate);

    bytes32 lastHashYaysAfter = chief.lastHashYays();

    assert lastHashYaysAfter == slate, "Assert 1";
}

// Verify revert rules on votePoll
rule voteSlate_revert(bytes32 slate) {
    env e;

    address delegate = delegate();

    vote@withrevert(e, slate);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != delegate;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting votePoll
rule votePollOne(uint256 pollId, uint256 optionId) {
    env e;

    votePoll(e, pollId, optionId);

    uint256 lastPollIdAfter = polling.lastPollId();
    uint256 lastOptionIdAfter = polling.lastOptionId();

    assert lastPollIdAfter == pollId, "Assert 1";
    assert lastOptionIdAfter == optionId, "Assert 2";
}

// Verify revert rules on votePoll
rule votePollOne_revert(uint256 pollId, uint256 optionId) {
    env e;

    address delegate = delegate();

    votePoll@withrevert(e, pollId, optionId);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != delegate;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}

// Verify correct storage changes for non reverting votePoll
rule votePollMultiple(uint256[] pollIds, uint256[] optionIds) {
    env e;

    bytes32 hashPollIds = polling.calculateHash(pollIds);
    bytes32 hashOptionIds = polling.calculateHash(optionIds);

    votePoll(e, pollIds, optionIds);

    bytes32 lastHashPollIdsAfter = polling.lastHashPollIds();
    bytes32 lastHashOptionIdsAfter = polling.lastHashOptionIds();

    assert lastHashPollIdsAfter == hashPollIds, "Assert 1";
    assert lastHashOptionIdsAfter == hashOptionIds, "Assert 2";
}

// Verify revert rules on votePoll
rule votePollMultiple_revert(uint256[] pollIds, uint256[] optionIds) {
    env e;

    address delegate = delegate();

    votePoll@withrevert(e, pollIds, optionIds);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != delegate;

    assert lastReverted <=> revert1 || revert2, "Revert rules failed";
}
