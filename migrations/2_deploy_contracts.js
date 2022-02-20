const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');

module.exports = function(deployer) {

    let firstAirline = "0x14888f4120783A91fC2b43d850E2d2E331efD574";
    deployer.deploy(FlightSuretyData, firstAirline).then(() => {
      return deployer
        .deploy(FlightSuretyApp, FlightSuretyData.address)
        .then(() => {
          let config = {
            localhost: {
              url: "http://localhost:8545",
              dataAddress: FlightSuretyData.address,
              appAddress: FlightSuretyApp.address,
            },
          };
          fs.writeFileSync(
            __dirname + "/../src/dapp/config.json",
            JSON.stringify(config, null, "\t"),
            "utf-8"
          );
          fs.writeFileSync(
            __dirname + "/../src/server/config.json",
            JSON.stringify(config, null, "\t"),
            "utf-8"
          );
        });
    });
}