// VoteDelegateFactory - create and keep record of proxy identities
pragma solidity ^0.4.24;

import "./VoteDelegate.sol";

contract VoteDelegateFactory {
    DSChief public chief;
    mapping(address => VoteDelegate) public hotMap;
    mapping(address => VoteDelegate) public coldMap;
    mapping(address => address) public linkRequests;

    event LinkRequested(address indexed cold, address indexed hot);
    event LinkConfirmed(address indexed cold, address indexed hot, address indexed voteDelegate);

    constructor(DSChief chief_) public { chief = chief_; }

    function hasProxy(address guy) public view returns (bool) {
        return (coldMap[guy] != address(0) || hotMap[guy] != address(0));
    }

    function initiateLink(address hot) public {
        require(!hasProxy(msg.sender), "Cold wallet is already linked to another Vote Proxy");
        require(!hasProxy(hot), "Hot wallet is already linked to another Vote Proxy");

        linkRequests[msg.sender] = hot;
        emit LinkRequested(msg.sender, hot);
    }

    function approveLink(address cold) public returns (VoteDelegate voteDelegate) {
        require(linkRequests[cold] == msg.sender, "Cold wallet must initiate a link first");
        require(!hasProxy(msg.sender), "Hot wallet is already linked to another Vote Proxy");

        voteDelegate = new VoteDelegate(chief, cold, msg.sender);
        hotMap[msg.sender] = voteDelegate;
        coldMap[cold] = voteDelegate;
        delete linkRequests[cold];
        emit LinkConfirmed(cold, msg.sender, voteDelegate);
    }

    function breakLink() public {
        require(hasProxy(msg.sender), "No VoteDelegate found for this sender");

        VoteDelegate voteDelegate = coldMap[msg.sender] != address(0)
            ? coldMap[msg.sender] : hotMap[msg.sender];
        address cold = voteDelegate.cold();
        address hot = voteDelegate.hot();
        require(chief.deposits(voteDelegate) == 0, "VoteDelegate still has funds attached to it");

        delete coldMap[cold];
        delete hotMap[hot];
    }

    function linkSelf() public returns (VoteDelegate voteDelegate) {
        initiateLink(msg.sender);
        return approveLink(msg.sender);
    }
}
