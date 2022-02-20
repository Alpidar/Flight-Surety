const FlightSuretyData = artifacts.require("FlightSuretyData");
const FlightSuretyApp = artifacts.require("FlightSuretyApp");

contract("Oracles", async (accounts) => {
  const TEST_ORACLES_COUNT = 31;
  // Watch contract events
  const STATUS_CODE_UNKNOWN = 0;
  const STATUS_CODE_ON_TIME = 10;
  const STATUS_CODE_LATE_AIRLINE = 20;
  const STATUS_CODE_LATE_WEATHER = 30;
  const STATUS_CODE_LATE_TECHNICAL = 40;
  const STATUS_CODE_LATE_OTHER = 50;

  const takeOff = Math.floor(Date.now() / 1000) + 1000;
  const timestamp = takeOff + 1000;
  const from = "NY";
  const destination = "NJ";
  const flight = "TEST123";
  const ticketPrice = web3.utils.toWei("0.1", "ether");
  const insurance = web3.utils.toWei("0.1", "ether");

  let firstAirline = accounts[1];
  let dataInstance;
  let appInstance;
  beforeEach("setup contract", async () => {
    dataInstance = await FlightSuretyData.deployed();
    appInstance = await FlightSuretyApp.deployed();
    await dataInstance.authorizeCaller(appInstance.address, {
      from: accounts[0],
    });

    // // provide funding
    // await appInstance.fund({
    //   from: firstAirline,
    //   value: web3.utils.toWei("10", "ether"),
    // });
    // // register flight
    // await appInstance.registerFlight(
    //   takeOff,
    //   timestamp,
    //   flight,
    //   ticketPrice,
    //   from,
    //   destination,
    //   { from: firstAirline }
    // );

    // // buy ticket
    // appInstance.buy(flight, destination, timestamp, insurance, {
    //   from: accounts[7],
    //   value: +ticketPrice + +insurance,
    // });
  });

  it("can register oracles", async () => {
    // ARRANGE
    let fee = await appInstance.REGISTRATION_FEE.call();
    // ACT
    for (let a = 10; a < TEST_ORACLES_COUNT; a++) {
      const tx = await appInstance.registerOracle({
        from: accounts[a],
        value: fee,
      });
      let result = await appInstance.getIndexes.call({
        from: accounts[a],
      });
      const {
        args: { indexes },
      } = tx.logs[0];
      console.log(
        `Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`
      );
      assert.equal(+indexes[0], +result[0]);
      assert.equal(+indexes[1], +result[1]);
      assert.equal(+indexes[2], +result[2]);
    }
  });

  it("can request flight status", async () => {
    // Submit a request for oracles to get status information for a flight
    await appInstance.fetchFlightStatus(flight, destination, timestamp, {
      from: accounts[0],
    });
    // ACT

    // Since the Index assigned to each test account is opaque by design
    // loop through all the accounts and for each account, all its Indexes (indices?)
    // and submit a response. The contract will reject a submission if it was
    // not requested so while sub-optimal, it's a good test of that feature
    for (let a = 10; a < TEST_ORACLES_COUNT; a++) {
      // Get oracle information
      let oracleIndexes = await appInstance.getIndexes.call({
        from: accounts[a],
      });
      for (let idx = 0; idx < 3; idx++) {
        try {
          // Submit a response...it will only be accepted if there is an Index match
          await appInstance.submitOracleResponse(
            oracleIndexes[idx],
            flight,
            destination,
            timestamp,
            STATUS_CODE_LATE_AIRLINE,
            { from: accounts[a] }
          );
        } catch (e) {
          // Enable this when debugging
          console.log(
            "\nError",
            idx,
            oracleIndexes[idx].toNumber(),
            flight,
            timestamp
          );
        }
      }
    }
  });

  it("Updates Flight Status with enough responses", async () => {
    const key = await dataInstance.getFlightKey(flight, destination, timestamp);
    const flightStruct = await dataInstance.flights(key);
    assert.equal(+flightStruct.statusCode, STATUS_CODE_LATE_AIRLINE);
  });

});
