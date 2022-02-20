// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.9.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) public multiCallers;
    
    struct Airline {
        bool registered;
        bool funded;
    }

    mapping(address => Airline) public airlines;
    uint public registeredAirlines;
    address public firstAirline;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 takeOff;
        uint256 landing;
        address airline;
        string flightRef;
        uint price;
        string from;
        string to;
        mapping(address => bool) bookings;
        mapping(address => uint) insurances;

    }

    address[] internal passengers;
    mapping(bytes32 => Flight) public flights;
    bytes32[] public flightKeys;
    uint public indexFlightKeys = 0;
    mapping(address => uint) public withdrawals;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event Paid(address recipient, uint amount);
    event Funded(address airline);
    event AirlineRegistered(address origin, address newAirline);
    event Credited(address passenger, uint amount);
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address _firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        firstAirline = _firstAirline;
        registeredAirlines = 1;
        airlines[firstAirline].registered = true;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier flightRegistered(bytes32 flightKey) {
        require(flights[flightKey].isRegistered, "Flight does not exist");
        _;
    }

    modifier authorizedCaller() {
        require(multiCallers[msg.sender] == true, "Address not authorized");
        _;
    }

    modifier valWithinRange(uint val, uint low, uint up) {
        require(val < up, "Value higher than max allowed");
        require(val > low, "Value lower than min allowed");
        _;
    }

    modifier notProcessed(bytes32 flightKey) {
        require(flights[flightKey].statusCode == 0, "This flight has already been processed");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        require(mode != operational, "Mode already in use");
        operational = mode;
    }

    function hasFunded (address airlineAddress) external view returns (bool _hasFunded){
        _hasFunded = airlines[airlineAddress].funded;
    }

    function isRegistered(address airlineAddress) external view returns (bool _registered){
        _registered = airlines[airlineAddress].registered;
    }

    function subscribedInsurance (string memory flightRef, string memory destination, uint256 timestamp, address passenger) public view returns(uint amount){
        bytes32 flightKey = getFlightKey(flightRef, destination, timestamp);
        amount = flights[flightKey].insurances[passenger];
    }

    function getFlightPrice (bytes32 flightKey) external view returns (uint price){
        price = flights[flightKey].price;
    }

    function authorizeCaller (address callerAddress) public requireContractOwner requireIsOperational{
        multiCallers[callerAddress] = true;
    }

    function paxOnFlight (string memory flightRef, string memory destination, uint256 timestamp, address passenger ) public view returns(bool onFlight){
        bytes32 flightKey = getFlightKey(flightRef, destination, timestamp);
        onFlight = flights[flightKey].bookings[passenger];
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address airlineAddress,
                                address originAddress   
                            )
                            public
                            requireIsOperational
                            authorizedCaller
    {
        registeredAirlines++;
        airlines[airlineAddress].registered = true;
        emit AirlineRegistered(originAddress, airlineAddress);
    }

    function registerFlight
    (
        uint _takeOff,
        uint _landing,
        string calldata _flight,
        uint _price,
        string calldata _from,
        string calldata _to,
        address originAddress
    )
    external
    requireIsOperational
    authorizedCaller
    returns(bytes32)
    {
        require(_takeOff > now, "A flight cannot take off in the past");
        require(_landing > _takeOff, "A flight cannot land before taking off");

        Flight memory flight = Flight(
            true,
            0,
            _takeOff,
            _landing,
            originAddress,
            _flight,
            _price,
            _from,
            _to
        );
        bytes32 flightKey = keccak256(abi.encodePacked(_flight, _to, _landing));
        flights[flightKey] = flight;
        indexFlightKeys = flightKeys.push(flightKey).sub(1);
        return flightKey;
        // emitted in app contract
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   
                                bytes32 flightKey, 
                                uint amount, 
                                address originAddress                          
                            )
                            public
                            requireIsOperational
                            authorizedCaller
                            flightRegistered(flightKey)
                            payable
    {
        Flight storage flight = flights[flightKey];
        flight.bookings[originAddress] = true;
        flight.insurances[originAddress] = amount;
        passengers.push(originAddress);
        withdrawals[flight.airline] = flight.price;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 flightKey
                                )
                                public
                                requireIsOperational
                                flightRegistered(flightKey)
    {
        Flight storage flight = flights[flightKey];
        for (uint i = 0; i < passengers.length; i++) {
            withdrawals[passengers[i]] = flight.insurances[passengers[i]];
            emit Credited(passengers[i], flight.insurances[passengers[i]]);
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address originAddress
                            )
                            external
                            requireIsOperational
                            // authorizedCaller
    {
        require(withdrawals[originAddress] > 0);
        uint amount = withdrawals[originAddress];
        withdrawals[originAddress] = 0;
        address(uint160(originAddress)).transfer(amount);
        emit Paid(originAddress, amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                                address originAddress
                            )
                            public
                            requireIsOperational
                            authorizedCaller
                            payable
    {
        airlines[originAddress].funded = true;
        emit Funded(originAddress);
    }

    function getFlightKey
                        (
                            string memory airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        public
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function changeStatus(bytes32 flightKey, uint8 statusCode) external flightRegistered(flightKey) requireIsOperational authorizedCaller notProcessed(flightKey) {
        Flight storage flight = flights[flightKey];
        flight.statusCode = statusCode;
        if (statusCode == 20) {
            creditInsurees(flightKey);
        }
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    // fallback() 
    //                         external 
    //                         payable 
    // {
    //     fund();
    // }


}

