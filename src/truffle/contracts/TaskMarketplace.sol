// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TaskMarketplace {
    struct Task {
        address creator;
        string description;
        uint256 reward;
        address worker;
        bool isCompleted;
        bool isPaid;
        uint256 completionTime;
        bool isDisputed;
        string disputeReason;
    }

    struct Arbitrator {
        bool isActive;
        uint256 stake;
    }

    mapping(address => Arbitrator) public arbitrators;
    address[] public arbitratorList;

    uint256 public constant DISPUTE_PERIOD = 60;
    uint256 public constant ARBITRATOR_FEE = 0.02 ether;

    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;

    event TaskCreated(uint256 taskId, address creator, string description, uint256 reward);
    event TaskAccepted(uint256 taskId, address worker);
    event TaskCompleted(uint256 taskId);
    event PaymentReleased(uint256 taskId, address worker, uint256 amount);
    event DisputeRaised(uint256 taskId, string reason);
    event DisputeResolved(uint256 taskId, bool workerPaid);
    event ArbitratorAdded(address arbitrator, uint256 stake);
    event ArbitratorRemoved(address arbitrator, uint256 returnedStake);

    function createTask(string memory _description) external payable {
        taskCount++;
        tasks[taskCount] = Task({
            creator: msg.sender,
            description: _description,
            reward: msg.value,
            worker: address(0),
            isCompleted: false,
            isPaid: false,
            completionTime: 0,
            isDisputed: false,
            disputeReason: ""
        });

        emit TaskCreated(taskCount, msg.sender, _description, msg.value);
    }

    function acceptTask(uint256 _taskId) external payable {
        Task storage task = tasks[_taskId];
        require(task.creator != address(0), "Task does not exist");
        require(task.worker == address(0), "Task already accepted");
        require(msg.sender != task.creator, "Creator cannot accept their own task");
        require(msg.value == ARBITRATOR_FEE, "Must provide arbitrator fee as stake");

        task.worker = msg.sender;
        emit TaskAccepted(_taskId, msg.sender);
    }

    function completeTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(msg.sender == task.worker, "Only assigned worker can mark task as completed");
        require(task.worker != address(0), "Task has not been accepted");
        require(!task.isCompleted, "Task is already completed");

        task.isCompleted = true;
        task.completionTime = block.timestamp;
        emit TaskCompleted(_taskId);
    }

    function becomeArbitrator() external payable {
        require(msg.value > 0, "Must provide stake to become an arbitrator");
        require(!arbitrators[msg.sender].isActive, "Already an active arbitrator");

        arbitrators[msg.sender] = Arbitrator({
            isActive: true,
            stake: msg.value
        });
        arbitratorList.push(msg.sender);

        emit ArbitratorAdded(msg.sender, msg.value);
    }

    function stopBeingArbitrator() external {
        require(arbitrators[msg.sender].isActive, "Not an active arbitrator");

        uint256 stake = arbitrators[msg.sender].stake;
        arbitrators[msg.sender].isActive = false;
        arbitrators[msg.sender].stake = 0;

        for (uint i = 0; i < arbitratorList.length; i++) {
            if (arbitratorList[i] == msg.sender) {
                arbitratorList[i] = arbitratorList[arbitratorList.length - 1];
                arbitratorList.pop();
                break;
            }
        }

        payable(msg.sender).transfer(stake);
        emit ArbitratorRemoved(msg.sender, stake);
    }

    function raiseDispute(uint256 _taskId, string memory _reason) external payable {
        Task storage task = tasks[_taskId];
        require(msg.sender == task.creator, "Only task creator can raise a dispute");
        require(task.isCompleted, "Task is not completed yet");
        require(!task.isPaid, "Payment already released");
        require(!task.isDisputed, "Dispute already raised");
        require(block.timestamp <= task.completionTime + DISPUTE_PERIOD, "Dispute period has ended");
        require(msg.value == ARBITRATOR_FEE, "Must provide arbitrator fee as stake");

        task.isDisputed = true;
        task.disputeReason = _reason;
        emit DisputeRaised(_taskId, _reason);
    }

    function selectArbitrators() public view returns (address[3] memory) {
        require(arbitratorList.length >= 3, "Not enough arbitrators");

        // Randomly select 10 arbitrators (or less if less than 10 are available)
        uint256 selectCount = arbitratorList.length < 10 ? arbitratorList.length : 10;
        address[] memory selectedArbitrators = new address[](selectCount);
        uint256[] memory indices = new uint256[](arbitratorList.length);
        
        for (uint256 i = 0; i < arbitratorList.length; i++) {
            indices[i] = i;
        }

        for (uint256 i = 0; i < 10; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, i))) % (arbitratorList.length - i);
            selectedArbitrators[i] = arbitratorList[indices[randomIndex]];
            indices[randomIndex] = indices[arbitratorList.length - i - 1];
        }

        // Select top 3 arbitrators with highest stakes
        address[3] memory topThree;
        for (uint256 i = 0; i < 3; i++) {
            uint256 maxStake = 0;
            uint256 maxIndex = 0;
            for (uint256 j = 0; j < 10; j++) {
                if (selectedArbitrators[j] != address(0) && arbitrators[selectedArbitrators[j]].stake > maxStake) {
                    maxStake = arbitrators[selectedArbitrators[j]].stake;
                    maxIndex = j;
                }
            }
            topThree[i] = selectedArbitrators[maxIndex];
            selectedArbitrators[maxIndex] = address(0); // Mark this arbitrator as selected
        }

        return topThree;
    }

    // function resolveDispute(uint256 _taskId, address _recipient) external {
    //     require(msg.sender == arbitrator, "Only the arbitrator can resolve disputes");
    //     Task storage task = tasks[_taskId];
    //     require(task.isDisputed, "No active dispute for this task");
    //     require(_recipient == task.worker || _recipient == task.creator, "Invalid recipient");

    //     task.isDisputed = false;
    //     task.isPaid = true;

    //     // Winning party gets the reward + original arbitrator fee
    //     uint256 paymentAmount = task.reward + ARBITRATOR_FEE;
    //     task.reward = 0;
        
    //     // Arbitrator gets the arbitrator fee from the losing party
    //     payable(arbitrator).transfer(ARBITRATOR_FEE);
    //     payable(_recipient).transfer(paymentAmount);

    //     emit DisputeResolved(_taskId, _recipient == task.worker);
    // }

    function releasePayment(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(
            msg.sender == task.creator ||
            (msg.sender == task.worker && block.timestamp > task.completionTime + DISPUTE_PERIOD),
            "Not authorized to release payment"
        );
        require(task.isCompleted, "Task is not completed");
        require(!task.isPaid, "Payment already released");
        require(!task.isDisputed, "Task is currently disputed");

        task.isPaid = true;
        
        payable(task.creator).transfer(ARBITRATOR_FEE);
        payable(task.worker).transfer(task.reward + ARBITRATOR_FEE);
        
        emit PaymentReleased(_taskId, task.worker, task.reward);
    }

    function getTask(uint256 _taskId) external view returns (Task memory) {
        require(tasks[_taskId].creator != address(0), "Task does not exist");
        return tasks[_taskId];
    }
}