// const { assert } = require("chai");

// const FlightSuretyData = artifacts.require("FlightSuretyData");
// const FlightSuretyApp = artifacts.require("FlightSuretyApp");

// contract("Flight Surety Tests", async (accounts) => {
  // let dataInstance;
  // let firstAirline = accounts[1];
  // const takeOff = Math.floor(Date.now() / 1000) + 1000;
  // const landing = takeOff + 1000;
  // const from = "NY";
  // const to = "NJ";
  // const flightRef = "TEST123";

  // beforeEach("setup contract", async () => {
  //   dataInstance = await FlightSuretyData.deployed();
  //   appInstance = await FlightSuretyApp.deployed();
  //   await dataInstance.authorizeCaller(appInstance.address, {
  //     from: accounts[0],
  //   });
  // });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  // it(`(multiparty) has correct initial isOperational() value`, async function () {
  //   // Get operating status
  //   let status = await dataInstance.isOperational.call();
  //   assert.equal(status, true, "Incorrect initial operating status value");
  // });

  // it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
  //   // Ensure that access is denied for non-Contract Owner account
  //   let accessDenied = false;
  //   try {
  //     await dataInstance.setOperatingStatus(false, { from: accounts[2] });
  //   } catch (e) {
  //     accessDenied = true;
  //   }
  //   assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  // });

  // it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
  //   // Ensure that access is allowed for Contract Owner account
  //   let accessDenied = false;
  //   try {
  //     await dataInstance.setOperatingStatus(false, { from: accounts[0] });
  //   } catch (e) {
  //     accessDenied = true;
  //   }
  //   assert.equal(
  //     accessDenied,
  //     false,
  //     "Access not restricted to Contract Owner"
  //   );
  // });

  // it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
  //   await dataInstance.setOperatingStatus(false, { from: accounts[0] });

  //   let reverted = false;
  //   try {
  //     await dataInstance.setTestingMode(true);
  //   } catch (e) {
  //     reverted = true;
  //   }
  //   assert.equal(reverted, true, "Access not blocked for requireIsOperational");

  //   // Set it back for other tests to work
  //   await dataInstance.setOperatingStatus(true);
  // });

  // it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
  //   // ARRANGE
  //   let newAirline = accounts[2];

  //   // ACT
  //   try {
  //     await appInstance.registerAirline(newAirline, { from: firstAirline });
  //   } catch (e) {}
  //   let result = await dataInstance.airlines(newAirline);

  //   // ASSERT
  //   assert.equal(
  //     result.registered,
  //     false,
  //     "Airline should not be able to register another airline if it hasn't provided funding"
  //   );
  // });

  // it("Registers first airline at deployment", async () => {
  //   assert.equal(await dataInstance.firstAirline(), firstAirline);
  //   assert.equal(await dataInstance.registeredAirlines(), 1);
  //   const _firstAirline = await dataInstance.airlines(firstAirline);
  //   assert(await _firstAirline.registered);
  // });

  // it("Airline provides funding", async () => {
  //   const fund = web3.utils.toWei("10", "ether");

  //   const balanceBefore = await web3.eth.getBalance(dataInstance.address);

  //   await dataInstance.authorizeCaller(firstAirline, { from: accounts[0] });

  //   await appInstance.fund({
  //     from: firstAirline,
  //     value: fund,
  //   });

  //   const airline = await dataInstance.airlines(firstAirline);
  //   assert(airline.funded);

  //   const balanceAfter = await web3.eth.getBalance(dataInstance.address);
  //   assert.equal(+balanceBefore + fund, +balanceAfter);
  // });

  // it("Only existing airline may register a new airline until there are at least four airlines registered", async () => {
  //   await appInstance.registerAirline(accounts[2], { from: firstAirline });
  //   const airline = await dataInstance.airlines(accounts[2]);
  //   assert(await airline.registered);

  //   try {
  //     await appInstance.registerAirline(accounts[3], {
  //       from: accounts[4],
  //     });
  //   } catch (error) {
  //     assert(
  //       error.message.includes("Airline not registered"),
  //       `${error.message}`
  //     );
  //   }
  // });

  // it("Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines", async () => {
  //   // register airlines to meet total 4 airline requirement
  //   await appInstance.registerAirline(accounts[3], { from: firstAirline });
  //   await appInstance.registerAirline(accounts[4], { from: firstAirline });
  //   assert((await dataInstance.registeredAirlines()) >= 4);
  //   // try registering by first airline
  //   await appInstance.registerAirline(accounts[5], { from: firstAirline });
  //   const first_result = await dataInstance.isRegistered(accounts[5]);
  //   assert.equal(first_result, false);
  //   // try registering by two airlines, which is 50% of total so far.
  //   await appInstance.fund({
  //     from: accounts[2],
  //     value: web3.utils.toWei("10", "ether"),
  //   });
  //   await appInstance.registerAirline(accounts[5], { from: accounts[2] });
  //   assert(await dataInstance.isRegistered(accounts[5]));
  // });

  // it("Airline can be registered, but does not participate in contract until it submits funding of 10 ether", async () => {
  //   // register flight without funding
  //   let initial = false;
  //   try {
  //     await appInstance.registerFlight(
  //       takeOff,
  //       landing,
  //       flightRef,
  //       web3.utils.toWei("0.1", "ether"),
  //       from,
  //       to,
  //       { from: accounts[3] }
  //     );
  //   } catch (error) {
  //     initial = true;
  //   }
  //   assert(initial);

  //   //register flight after funding
  //   await appInstance.fund({
  //     from: accounts[3],
  //     value: web3.utils.toWei("10", "ether"),
  //   });

  //   await appInstance.registerFlight(
  //     takeOff,
  //     landing,
  //     flightRef,
  //     web3.utils.toWei("0.1", "ether"),
  //     from,
  //     to,
  //     { from: accounts[3] }
  //   );
  //   const flightKey = await dataInstance.getFlightKey(flightRef, to, landing);
  //   const flight = await dataInstance.flights(flightKey);
  //   assert(flight.isRegistered);
  // });

  // it("pasenger can buy airline ticket", async () => {
  //   await appInstance.buy(
  //     flightRef,
  //     to,
  //     landing,
  //     web3.utils.toWei("0.1", "ether"),
  //     {
  //       from: accounts[6],
  //       value: +web3.utils.toWei("0.2", "ether"), // ticket + insurance
  //     }
  //   );
  //   const isTicketBought = await dataInstance.paxOnFlight(
  //     flightRef,
  //     to,
  //     landing,
  //     accounts[6]
  //   );
  //   assert(isTicketBought);
  // });

  // it("Passenger can subscribe to an insurance", async () => {
  //   const insuranceCredit = await dataInstance.subscribedInsurance(
  //     flightRef,
  //     to,
  //     landing,
  //     accounts[6]
  //   );
  //   assert.equal(
  //     +insuranceCredit,
  //     Math.floor(+(web3.utils.toWei("0.1", "ether") * 3) / 2)
  //   );
  // });

  // it("passenger can withdraw amount owed to them", async () => {
  //   const flightKey = await dataInstance.getFlightKey(flightRef, to, landing);
  //   await dataInstance.creditInsurees(flightKey);

  //   const initial_balance = await web3.eth.getBalance(accounts[6]);
  //   const amount = await dataInstance.withdrawals(accounts[6]);

  //   await appInstance.withdraw({ from: accounts[6] });

  //   const final_balance = await web3.eth.getBalance(accounts[6]);
  //   assert(+final_balance > +initial_balance);
  // });
// });
