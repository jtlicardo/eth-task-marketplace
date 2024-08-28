<template>
  <v-container>
    <v-row>
      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>Create Task</v-card-title>
          <v-card-text>
            <v-text-field
              v-model="newTask.description"
              label="Task Description"
            ></v-text-field>
            <v-text-field
              v-model="newTask.reward"
              label="Reward (ETH)"
              type="number"
            ></v-text-field>
            <v-btn color="primary" @click="createTask">Create Task</v-btn>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>Task List</v-card-title>
          <v-card-text>
            <v-list>
              <v-list-item v-for="task in tasks" :key="task.id">
                <v-list-item-content>
                  <v-list-item-title>{{ task.description }}</v-list-item-title>
                  <v-list-item-subtitle
                    >Reward: {{ task.reward }} ETH</v-list-item-subtitle
                  >
                </v-list-item-content>
                <v-list-item-action>
                  <v-btn
                    v-if="!task.worker"
                    color="success"
                    @click="acceptTask(task.id)"
                    >Accept</v-btn
                  >
                  <v-btn
                    v-else-if="task.worker === account && !task.isCompleted"
                    color="info"
                    @click="completeTask(task.id)"
                    >Complete</v-btn
                  >
                  <v-btn
                    v-else-if="task.isCompleted && !task.isPaid"
                    color="warning"
                    @click="releasePayment(task.id)"
                    >Release Payment</v-btn
                  >
                </v-list-item-action>
              </v-list-item>
            </v-list>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script>
import Web3 from "web3";
import TaskMarketplaceJSON from "@/truffle/build/contracts/TaskMarketplace.json";

export default {
  data() {
    return {
      web3: null,
      contract: null,
      account: null,
      tasks: [],
      newTask: {
        description: "",
        reward: 0,
      },
    };
  },
  async mounted() {
    await this.initWeb3();
    await this.loadTasks();
  },
  methods: {
    async initWeb3() {
      if (window.ethereum) {
        this.web3 = new Web3(window.ethereum);
        try {
          await window.ethereum.enable();
          const accounts = await this.web3.eth.getAccounts();
          this.account = accounts[0];

          const contractABI = TaskMarketplaceJSON.abi;
          const contractAddress = "0x15eA9f684947971835ebaAbaa53Ad7510f6CB8A8";
          this.contract = new this.web3.eth.Contract(
            contractABI,
            contractAddress
          );
        } catch (error) {
          console.error("User denied account access");
        }
      } else {
        console.log("Non-Ethereum browser detected. Consider trying MetaMask!");
      }
    },
    async loadTasks() {
      const taskCount = await this.contract.methods.taskCount().call();
      this.tasks = [];
      for (let i = 1; i <= taskCount; i++) {
        const task = await this.contract.methods.getTask(i).call();
        this.tasks.push({
          id: i,
          description: task.description,
          reward: this.web3.utils.fromWei(task.reward, "ether"),
          worker: task.worker,
          isCompleted: task.isCompleted,
          isPaid: task.isPaid,
        });
      }
    },
    async createTask() {
      try {
        await this.contract.methods.createTask(this.newTask.description).send({
          from: this.account,
          value: this.web3.utils.toWei(this.newTask.reward.toString(), "ether"),
        });
        this.newTask.description = "";
        this.newTask.reward = 0;
        await this.loadTasks();
      } catch (error) {
        console.error("Error creating task:", error);
      }
    },
    async acceptTask(taskId) {
      try {
        const arbitratorFee = await this.contract.methods
          .ARBITRATOR_FEE()
          .call();
        await this.contract.methods.acceptTask(taskId).send({
          from: this.account,
          value: arbitratorFee,
        });
        await this.loadTasks();
      } catch (error) {
        console.error("Error accepting task:", error);
      }
    },
    async completeTask(taskId) {
      try {
        await this.contract.methods.completeTask(taskId).send({
          from: this.account,
        });
        await this.loadTasks();
      } catch (error) {
        console.error("Error completing task:", error);
      }
    },
    async releasePayment(taskId) {
      try {
        await this.contract.methods.releasePayment(taskId).send({
          from: this.account,
        });
        await this.loadTasks();
      } catch (error) {
        console.error("Error releasing payment:", error);
      }
    },
  },
};
</script>
