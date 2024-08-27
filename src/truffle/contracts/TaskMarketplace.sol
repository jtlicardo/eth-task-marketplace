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

    uint256 public constant DISPUTE_PERIOD = 60;

    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;

    event TaskCreated(uint256 taskId, address creator, string description, uint256 reward);
    event TaskAccepted(uint256 taskId, address worker);
    event TaskCompleted(uint256 taskId);
    event PaymentReleased(uint256 taskId, address worker, uint256 amount);
    event DisputeRaised(uint256 taskId, string reason);
    event DisputeResolved(uint256 taskId, bool workerPaid);

    address public arbitrator;
    uint256 public arbitratorFee;

    constructor(address _arbitrator, uint256 _arbitratorFee) {
        arbitrator = _arbitrator;
        arbitratorFee = _arbitratorFee;
    }

    function createTask(string memory _description) external payable {
        require(msg.sender != arbitrator, "Arbitrator cannot create tasks");
        require(msg.value > arbitratorFee, "Reward must be greater than the arbitrator fee");

        taskCount++;
        tasks[taskCount] = Task({
            creator: msg.sender,
            description: _description,
            reward: msg.value - arbitratorFee,
            worker: address(0),
            isCompleted: false,
            isPaid: false,
            completionTime: 0,
            isDisputed: false,
            disputeReason: ""
        });

        emit TaskCreated(taskCount, msg.sender, _description, msg.value - arbitratorFee);
    }

    function acceptTask(uint256 _taskId) external {
        // storage = reference
        Task storage task = tasks[_taskId];
        require(msg.sender != arbitrator, "Arbitrator cannot accept tasks");
        require(task.creator != address(0), "Task does not exist");
        require(task.worker == address(0), "Task already accepted");
        require(msg.sender != task.creator, "Creator cannot accept their own task");

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

    function raiseDispute(uint256 _taskId, string memory _reason) external {
        Task storage task = tasks[_taskId];
        require(msg.sender == task.creator, "Only task creator can raise a dispute");
        require(task.isCompleted, "Task is not completed yet");
        require(!task.isPaid, "Payment already released");
        require(!task.isDisputed, "Dispute already raised");
        require(block.timestamp <= task.completionTime + DISPUTE_PERIOD, "Dispute period has ended");

        task.isDisputed = true;
        task.disputeReason = _reason;
        emit DisputeRaised(_taskId, _reason);
    }

    function resolveDispute(uint256 _taskId, address _recipient) external {
        require(msg.sender == arbitrator, "Only the arbitrator can resolve disputes");
        Task storage task = tasks[_taskId];
        require(task.isDisputed, "No active dispute for this task");
        require(_recipient == task.worker || _recipient == task.creator, "Invalid recipient");

        task.isDisputed = false;
        task.isPaid = true;

        uint256 paymentAmount = task.reward;
        task.reward = 0;
        
        payable(arbitrator).transfer(arbitratorFee);
        payable(_recipient).transfer(paymentAmount);

        emit DisputeResolved(_taskId, _recipient == task.worker);
    }

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
        
        payable(task.creator).transfer(arbitratorFee);
        payable(task.worker).transfer(task.reward);
        
        emit PaymentReleased(_taskId, task.worker, task.reward);
    }

    function getTask(uint256 _taskId) external view returns (Task memory) {
        require(tasks[_taskId].creator != address(0), "Task does not exist");
        return tasks[_taskId];
    }
}