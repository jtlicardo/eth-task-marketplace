<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <v-alert v-if="account" type="info" outlined>
          Current account: {{ account }}
        </v-alert>
        <v-alert v-else type="warning" outlined>
          No account connected. Please connect to MetaMask.
        </v-alert>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>Create task</v-card-title>
          <v-card-text>
            <v-text-field
              v-model="newTask.description"
              label="Task description"
            ></v-text-field>
            <v-text-field
              v-model="newTask.reward"
              label="Reward (ETH)"
              type="number"
            ></v-text-field>
            <v-btn color="primary" @click="createTask">Create task</v-btn>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>Arbitrator actions</v-card-title>
          <v-card-text>
            <v-text-field
              v-model="arbitratorStake"
              label="Stake (ETH)"
              type="number"
              :disabled="isArbitrator"
            ></v-text-field>
            <v-btn
              v-if="!isArbitrator"
              color="primary"
              @click="becomeArbitrator"
              >Become arbitrator</v-btn
            >
            <v-btn
              v-if="isArbitrator"
              color="error"
              @click="stopBeingArbitrator"
              >Stop being arbitrator</v-btn
            >
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>Arbitrator status</v-card-title>
          <v-card-text>
            <v-alert v-if="isArbitrator" type="success" outlined>
              You are currently an arbitrator with a stake of
              {{ arbitratorStakeAmount }} ETH.
            </v-alert>
            <v-alert v-else type="info" outlined>
              You are not currently an arbitrator.
            </v-alert>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row>
      <v-col cols="12">
        <v-card>
          <v-card-title>Task list</v-card-title>
          <v-card-text>
            <v-list>
              <v-list-item v-for="task in tasks" :key="task.id" class="mb-4">
                <v-list-item-content>
                  <v-list-item-title class="d-flex align-center mb-2">
                    {{ task.description }}
                    <v-chip class="ml-2" color="primary" small>
                      {{ task.reward }} ETH
                    </v-chip>
                    <v-chip
                      v-if="task.creator === account"
                      class="ml-2"
                      color="secondary"
                      small
                    >
                      Your task
                    </v-chip>
                  </v-list-item-title>
                  <v-list-item-subtitle class="d-flex align-center mb-2">
                    Status:
                    <v-icon
                      :color="getTaskStatus(task).color"
                      small
                      class="ml-1 mr-1"
                    >
                      mdi-circle
                    </v-icon>
                    {{ getTaskStatus(task).text }}
                  </v-list-item-subtitle>
                  <v-list-item-subtitle>
                    Creator: {{ shortenAddress(task.creator) }}
                  </v-list-item-subtitle>
                  <v-list-item-subtitle v-if="!isZeroAddress(task.worker)">
                    Worker: {{ shortenAddress(task.worker) }}
                  </v-list-item-subtitle>
                  <v-list-item-subtitle v-if="task.isDisputed">
                    Dispute reason: {{ task.disputeReason }}
                  </v-list-item-subtitle>
                  <v-list-item-subtitle v-if="task.isDisputed && task.arbitrators.length > 0" class="mt-2">
                    Arbitrators:
                    <v-chip v-for="(arbitrator, index) in task.arbitrators" :key="index" class="mr-1 mb-1" small>
                      {{ shortenAddress(arbitrator) }}
                    </v-chip>
                  </v-list-item-subtitle>
                </v-list-item-content>
                <v-list-item-action class="mt-2">
                  <v-btn
                    v-if="
                      isZeroAddress(task.worker) && task.creator !== account
                    "
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
                  <v-btn
                    v-if="canRaiseDispute(task)"
                    color="error"
                    @click="raiseDispute(task.id)"
                    class="ml-2"
                    >Raise dispute</v-btn
                  >
                </v-list-item-action>
                <v-divider class="mt-4"></v-divider>
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

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

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
      arbitratorStake: 0,
      isArbitrator: false,
      arbitratorStakeAmount: 0,
    };
  },
  async mounted() {
    await this.initWeb3();
    await this.loadTasks();
    await this.checkArbitratorStatus();
  },
  methods: {
    isZeroAddress(address) {
      return address === ZERO_ADDRESS;
    },
    async initWeb3() {
      if (window.ethereum) {
        this.web3 = new Web3(window.ethereum);
        try {
          await window.ethereum.enable();
          const accounts = await this.web3.eth.getAccounts();
          this.account = accounts[0];

          const contractABI = TaskMarketplaceJSON.abi;
          const contractAddress = "0xc6838ff47eeBe5787af36E1c2734DD8f7aaE02D5";
          this.contract = new this.web3.eth.Contract(
            contractABI,
            contractAddress
          );

          // Add event listener for account changes
          window.ethereum.on("accountsChanged", () => {
            window.location.reload();
          });
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
        let arbitrators = [];
        if (task.isDisputed) {
          arbitrators = await this.getDisputeArbitrators(i);
        }
        this.tasks.push({
          id: i,
          description: task.description,
          reward: this.web3.utils.fromWei(task.reward, "ether"),
          creator: task.creator,
          worker: task.worker,
          isCompleted: task.isCompleted,
          isPaid: task.isPaid,
          isDisputed: task.isDisputed,
          disputeReason: task.disputeReason,
          completionTime: parseInt(task.completionTime),
          arbitrators: arbitrators,
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
    async checkArbitratorStatus() {
      if (this.account) {
        const arbitrator = await this.contract.methods
          .arbitrators(this.account)
          .call();
        this.isArbitrator = arbitrator.isActive;
        this.arbitratorStakeAmount = this.web3.utils.fromWei(
          arbitrator.stake,
          "ether"
        );
        if (this.isArbitrator) {
          this.arbitratorStake = 0;
        }
      }
    },

    async becomeArbitrator() {
      try {
        await this.contract.methods.becomeArbitrator().send({
          from: this.account,
          value: this.web3.utils.toWei(
            this.arbitratorStake.toString(),
            "ether"
          ),
        });
        await this.checkArbitratorStatus();
      } catch (error) {
        console.error("Error becoming arbitrator:", error);
      }
    },

    async stopBeingArbitrator() {
      try {
        await this.contract.methods.stopBeingArbitrator().send({
          from: this.account,
        });
        await this.checkArbitratorStatus();
      } catch (error) {
        console.error("Error stopping being arbitrator:", error);
      }
    },
    canRaiseDispute(task) {
      return (
        task.creator === this.account &&
        task.isCompleted &&
        !task.isPaid &&
        !task.isDisputed &&
        Date.now() / 1000 <= task.completionTime + 600 // 10 minute dispute period
      );
    },

    async raiseDispute(taskId) {
      try {
        const reason = prompt("Please enter the reason for raising a dispute:");
        if (reason) {
          const arbitratorFee = await this.contract.methods
            .ARBITRATOR_FEE()
            .call();
          await this.contract.methods.raiseDispute(taskId, reason).send({
            from: this.account,
            value: arbitratorFee,
          });
          await this.loadTasks();
        }
      } catch (error) {
        console.error("Error raising dispute:", error);
      }
    },
    getTaskStatus(task) {
      if (task.isPaid) {
        return { color: "green", text: "Completed and paid" };
      } else if (task.isDisputed) {
        return { color: "red", text: "Disputed" };
      } else if (task.isCompleted) {
        return { color: "orange", text: "Completed (awaiting payment)" };
      } else if (!this.isZeroAddress(task.worker)) {
        return { color: "blue", text: "In progress" };
      } else {
        return { color: "grey", text: "Open" };
      }
    },
    async getDisputeArbitrators(taskId) {
      try {
        const arbitrators = await this.contract.methods.getDisputeArbitrators(taskId).call();
        return arbitrators.filter(addr => !this.isZeroAddress(addr));
      } catch (error) {
        console.error("Error fetching dispute arbitrators:", error);
        return [];
      }
    },
    shortenAddress(address) {
      if (!address) return '';
      return `${address.substr(0, 6)}...${address.substr(-4)}`;
    },
  },
};
</script>
