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
    }

    mapping(uint256 => Task) public tasks;
    uint256 public taskCount;

    event TaskCreated(uint256 taskId, address creator, string description, uint256 reward);
    event TaskAccepted(uint256 taskId, address worker);
    event TaskCompleted(uint256 taskId);
    event PaymentReleased(uint256 taskId, address worker, uint256 amount);

    function createTask(string memory _description) external payable {
        require(msg.value > 0, "Reward must be greater than 0");

        taskCount++;
        tasks[taskCount] = Task({
            creator: msg.sender,
            description: _description,
            reward: msg.value,
            worker: address(0),
            isCompleted: false,
            isPaid: false
        });

        emit TaskCreated(taskCount, msg.sender, _description, msg.value);
    }

    function acceptTask(uint256 _taskId) external {
        // storage = reference
        Task storage task = tasks[_taskId];
        require(task.creator != address(0), "Task does not exist");
        require(task.worker == address(0), "Task already accepted");
        require(msg.sender != task.creator, "Creator cannot accept their own task");

        task.worker = msg.sender;
        emit TaskAccepted(_taskId, msg.sender);
    }

    function completeTask(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(msg.sender == task.creator, "Only creator can mark task as completed");
        require(task.worker != address(0), "Task has not been accepted");
        require(!task.isCompleted, "Task is already completed");

        task.isCompleted = true;
        emit TaskCompleted(_taskId);
    }

    function releasePayment(uint256 _taskId) external {
        Task storage task = tasks[_taskId];
        require(msg.sender == task.creator, "Only creator can release payment");
        require(task.isCompleted, "Task is not completed");
        require(!task.isPaid, "Payment already released");

        task.isPaid = true;
        payable(task.worker).transfer(task.reward);
        emit PaymentReleased(_taskId, task.worker, task.reward);
    }

    function getTask(uint256 _taskId) external view returns (Task memory) {
        require(tasks[_taskId].creator != address(0), "Task does not exist");
        return tasks[_taskId];
    }
}