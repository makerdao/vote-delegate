// VoteDelegate - delegate your vote
pragma solidity 0.6.12;

interface TokenLike {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external;
    function pull(address, uint256) external;
    function push(address, uint256) external;
    function transfer(address, uint256) external;
    function mint(address, uint256) external;
}

interface ChiefLike {
    function GOV() external view returns (TokenLike);
    function IOU() external view returns (TokenLike);
    function approvals(address) external view returns (uint256);
    function deposits(address) external view returns (uint256);
    function lock(uint256) external;
    function free(uint256) external;
    function vote(address[] calldata) external returns (bytes32);
    function vote(bytes32) external;
}

contract VoteDelegate {
    mapping(address => uint256) public delegators;
    address public immutable delegate;
    TokenLike public immutable gov;
    TokenLike public immutable iou;
    ChiefLike public immutable chief;

    constructor(address _chief, address _delegate) public {
        chief = ChiefLike(_chief);
        delegate = _delegate;

        gov = ChiefLike(_chief).GOV();
        iou = ChiefLike(_chief).IOU();

        ChiefLike(_chief).GOV().approve(_chief, uint256(-1));
        ChiefLike(_chief).IOU().approve(_chief, uint256(-1));
    }

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    modifier delegate_auth() {
        require(msg.sender == delegate, "Sender must be delegate");
        _;
    }

    function lock(uint256 wad) external {
        delegators[msg.sender] = add(delegators[msg.sender], wad);
        gov.pull(msg.sender, wad);
        chief.lock(wad);
        iou.push(msg.sender, wad);
    }

    function free(uint256 wad) external {
        delegators[msg.sender] = sub(delegators[msg.sender], wad);
        iou.pull(msg.sender, wad);
        chief.free(wad);
        gov.push(msg.sender, wad);
    }

    function vote(address[] memory yays) external delegate_auth returns (bytes32) {
        return chief.vote(yays);
    }

    function vote(bytes32 slate) external delegate_auth {
        chief.vote(slate);
    }
}
