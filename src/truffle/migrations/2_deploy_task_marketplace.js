const TaskMarketplace = artifacts.require("TaskMarketplace");

module.exports = function (deployer) {
  deployer.deploy(TaskMarketplace);
};
