// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title Simple Crowdfunding (Factory + Campaigns)
/// @author
/// @notice Create crowdfunding campaigns, allow people to contribute, allow creator to withdraw if goal reached, allow refunds if not.
contract Crowdfunding {
    uint256 public campaignCount;

    struct Campaign {
        uint256 id;
        address payable creator;
        string title;
        string description;
        uint256 goal;        // funding goal in wei
        uint256 pledged;     // total pledged in wei
        uint256 startAt;     // timestamp when campaign starts
        uint256 endAt;       // timestamp when campaign ends
        bool claimed;        // whether creator claimed funds
    }

    // campaignId => Campaign
    mapping(uint256 => Campaign) public campaigns;
    // campaignId => (contributor => amount)
    mapping(uint256 => mapping(address => uint256)) public contributions;

    /// Events
    event CampaignCreated(
        uint256 indexed id,
        address indexed creator,
        uint256 goal,
        uint256 startAt,
        uint256 endAt,
        string title
    );

    event Pledged(uint256 indexed id, address indexed contributor, uint256 amount);
    event Unpledged(uint256 indexed id, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed id, address indexed creator, uint256 amount);
    event RefundClaimed(uint256 indexed id, address indexed contributor, uint256 amount);

    /// Simple reentrancy guard
    uint256 private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "Reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /// Create a new campaign
    /// @param _title human readable title
    /// @param _description description
    /// @param _goal funding goal in wei
    /// @param _durationSeconds duration from now (in seconds)
    function createCampaign(
        string calldata _title,
        string calldata _description,
        uint256 _goal,
        uint256 _durationSeconds
    ) external {
        require(_goal > 0, "Goal must be > 0");
        require(_durationSeconds >= 1 hours, "Duration must be >= 1 hour");

        campaignCount += 1;
        uint256 id = campaignCount;

        uint256 startAt = block.timestamp;
        uint256 endAt = block.timestamp + _durationSeconds;

        campaigns[id] = Campaign({
            id: id,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            pledged: 0,
            startAt: startAt,
            endAt: endAt,
            claimed: false
        });

        emit CampaignCreated(id, msg.sender, _goal, startAt, endAt, _title);
    }

    /// Contribute to a campaign (payable)
    function pledge(uint256 _id) external payable nonReentrant {
        Campaign storage c = campaigns[_id];
        require(c.creator != address(0), "Campaign not found");
        require(block.timestamp >= c.startAt, "Campaign not started");
        require(block.timestamp <= c.endAt, "Campaign ended");
        require(msg.value > 0, "Must send ETH");

        contributions[_id][msg.sender] += msg.value;
        c.pledged += msg.value;

        emit Pledged(_id, msg.sender, msg.value);
    }

    /// Optional: allow contributor to reduce their pledge before campaign ends (partial refund to themselves)
    function unpledge(uint256 _id, uint256 _amount) external nonReentrant {
        Campaign storage c = campaigns[_id];
        require(c.creator != address(0), "Campaign not found");
        require(block.timestamp <= c.endAt, "Campaign ended");
        uint256 pledgedByUser = contributions[_id][msg.sender];
        require(pledgedByUser >= _amount && _amount > 0, "Invalid amount");

        contributions[_id][msg.sender] = pledgedByUser - _amount;
        c.pledged -= _amount;

        // send back to user
        (bool sent, ) = payable(msg.sender).call{value: _amount}("");
        require(sent, "Transfer failed");

        emit Unpledged(_id, msg.sender, _amount);
    }

    /// If campaign ended and pledged >= goal, creator can withdraw funds
    function withdraw(uint256 _id) external nonReentrant {
        Campaign storage c = campaigns[_id];
        require(c.creator != address(0), "Campaign not found");
        require(msg.sender == c.creator, "Only creator");
        require(block.timestamp > c.endAt, "Campaign not ended");
        require(c.pledged >= c.goal, "Goal not reached");
        require(!c.claimed, "Already claimed");

        uint256 amount = c.pledged;
        c.claimed = true;
        c.pledged = 0; // safety

        (bool sent, ) = c.creator.call{value: amount}("");
        require(sent, "Transfer failed");

        emit FundsWithdrawn(_id, c.creator, amount);
    }

    /// If campaign ended and goal not reached, contributors can claim refund
    function refund(uint256 _id) external nonReentrant {
        Campaign storage c = campaigns[_id];
        require(c.creator != address(0), "Campaign not found");
        require(block.timestamp > c.endAt, "Campaign not ended");
        require(c.pledged < c.goal, "Goal reached; no refunds");

        uint256 contributed = contributions[_id][msg.sender];
        require(contributed > 0, "No contribution");

        contributions[_id][msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{value: contributed}("");
        require(sent, "Refund transfer failed");

        emit RefundClaimed(_id, msg.sender, contributed);
    }

    /// View helper: contributor's contribution to a campaign
    function myContribution(uint256 _id, address _user) external view returns (uint256) {
        return contributions[_id][_user];
    }

    /// Fallback / receive (do not accept funds accidentally)
    receive() external payable {
        revert("Send ETH via pledge()");
    }

    fallback() external payable {
        revert("Send ETH via pledge()");
    }
}
