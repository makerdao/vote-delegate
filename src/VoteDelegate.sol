// VoteDelegate - delegate your vote
pragma solidity 0.5.11;

import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-chief/chief.sol";

contract VoteDelegate is DSMath {
    bool public abandoned;
    mapping(address => uint256) public delegators;
    address public delegate;
    address public factory;
    DSToken public gov;
    DSToken public iou;
    DSChief public chief;

    //TODO(godsflaw): test me
    constructor(DSChief _chief, address _delegate, address _factory) public {
        chief = _chief;
        delegate = _delegate;
        factory = _factory;
        abandoned = false;

        gov = chief.GOV();
        iou = chief.IOU();

        gov.approve(address(chief), uint256(-1));
        iou.approve(address(chief), uint256(-1));
    }

    //TODO(godsflaw): test me
    modifier delegate_auth() {
        require(msg.sender == delegate, "Sender must be delegate");
        _;
    }

    //TODO(godsflaw): test me
    modifier delegator_auth() {
        require(delegators[msg.sender] > 0, "Sender must be a delegator");
        _;
    }

    //TODO(godsflaw): test me
    modifier factory_auth() {
        require(msg.sender == factory, "Sender must be VoteDelegateFactory");
        _;
    }

    //TODO(godsflaw): test me
    function abandon() public factory_auth {
        abandoned = true;
    }

    //TODO(godsflaw): test me
    function lock(uint256 wad) public {
        delegators[msg.sender] = add(delegators[msg.sender], wad);
        gov.pull(msg.sender, wad);
        chief.lock(wad);
    }

    //TODO(godsflaw): test me
    function free(uint256 wad) public delegator_auth {
        delegators[msg.sender] = sub(delegators[msg.sender], wad);
        chief.free(wad);
        gov.push(msg.sender, wad);
    }

    //TODO(godsflaw): test me
    function vote(address[] memory yays) public delegate_auth returns (bytes32) {
        return chief.vote(yays);
    }

    //TODO(godsflaw): test me
    function vote(bytes32 slate) public delegate_auth {
        chief.vote(slate);
    }
}
