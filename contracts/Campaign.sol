// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15.0;

contract CampaignFactory {
    Campaign[] public deployedCampaigns;

    function createCampaign(
        uint256 _goal,
        uint256 _end,
        uint256 _minimum
    ) public returns (address) {
        Campaign newCampaign = new Campaign(_goal, _end, _minimum, msg.sender);
        deployedCampaigns.push(newCampaign);
        return address(newCampaign);
    }

    function getDeployedCampaign() external view returns (Campaign[] memory) {
        return deployedCampaigns;
    }
}

contract Campaign {
    struct Request {
        string description; // for what?
        uint256 amount; // how much?
        address payable recipient; // for who (supplier)?
        bool completed; // it is done?
        uint256 countApprovals; // number of approved votes
    }

    address public manager; // owner
    uint256 public goal; // target amount
    uint256 public pledged; // raised amount
    uint256 public startAt; // launch date
    uint256 public endAt; // deadline
    uint256 public minPledge; // minimum amount of contribution
    Request[] public requests; // requests of needs
    uint256 public countPledges; // number of contributors
    mapping(address => uint256) public pledgeOf; // contributors
    mapping(address => mapping(uint256 => bool)) public approvals; // requests voters
    bool public canceled; // it is paused?

    modifier restricted() {
        require(
            msg.sender == manager,
            "Permission denied: You do not own this campaign"
        );
        _;
    }

    modifier beforeed() {
        require(block.timestamp <= endAt, "Campaign has already ended");
        _;
    }

    modifier contributed() {
        require(
            pledgeOf[msg.sender] > 0,
            "You are not in the contributors list"
        );
        _;
    }

    modifier succeeded() {
        require(pledged >= goal, "Campaign has succeeded");
        _;
    }

    modifier notsucceeded() {
        require(
            pledged < goal,
            "You cannot withdraw, Campaign has not succeeded"
        );
        _;
    }

    modifier activated() {
        require(!canceled, "Campaign has canceled");
        _;
    }

    constructor(
        uint256 _goal,
        uint256 _end,
        uint256 _minimum,
        address _owner
    ) {
        require(_end > block.timestamp, "End time is less than current time");

        manager = _owner;
        goal = _goal;
        pledged = 0;
        startAt = block.timestamp;
        endAt = _end;
        minPledge = _minimum;
    }

    function cancel() external restricted activated notsucceeded {
        canceled = true;
    }

    function pledge() external payable beforeed activated {
        require(
            msg.value > minPledge && msg.value > 0,
            "Value is less than minimum contribution"
        );

        pledged += msg.value;
        if (pledgeOf[msg.sender] == 0) {
            countPledges++;
        }
        pledgeOf[msg.sender] += msg.value;
    }

    function refund() external payable beforeed contributed notsucceeded {
        uint256 bal = pledgeOf[msg.sender];
        address payable user = payable(msg.sender);
        user.transfer(bal);

        pledgeOf[msg.sender] = 0;
        countPledges--;
        pledged -= bal;
    }

    function createRequest(
        string memory _description,
        uint256 _amount,
        address payable _recipient
    ) external restricted succeeded activated {
        Request memory newRequest = Request({
            description: _description,
            amount: _amount,
            recipient: _recipient,
            completed: false,
            countApprovals: 0
        });

        requests.push(newRequest);
    }

    function approveRequest(uint256 _id) external contributed activated {
        Request storage request = requests[_id];

        require(!request.completed, "Request has been completed");
        require(
            !approvals[msg.sender][_id],
            "You have already approved the request"
        );

        approvals[msg.sender][_id] = true;
        request.countApprovals++;
    }

    function finalizeRequest(uint256 _id)
        external
        payable
        restricted
        activated
    {
        Request storage request = requests[_id];

        require(!request.completed, "Request has been completed");
        require(
            request.countApprovals > (countPledges / 2),
            "Request does not have enough approvals"
        );

        payable(request.recipient).transfer(request.amount);
        request.completed = true;
    }


    function getSummary()
        external
        view
        returns (
            uint256, // minPledge
            uint256, // balance
            uint256, // num of requests
            uint256, // num of contributors
            address // manager
        )
    {
        return (
            minPledge,
            address(this).balance,
            requests.length,
            countPledges,
            manager
        );
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getRequestsCount() external view returns (uint256) {
        return requests.length;
    }

    function getRequests() external view returns (Request[] memory) {
        return requests;
    }
}
