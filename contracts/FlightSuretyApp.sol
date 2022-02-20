// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.9.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    FlightSuretyData flightSuretyData;

    uint public minFund = 10 ether;
    bool public operational = true;
    mapping(address => address[]) internal votes;

    /********************************************************************************************/
    /*                                       Events                               */
    /********************************************************************************************/
    event FlightRegistered(string flightRef, string to, uint landing);
    event WithdrawRequest(address recipient);
    event FlightProcessed(string flight, string destination, uint timestamp, uint8 statusCode);
 
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
         // Modify to call data contract's status
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

    modifier enoughFund() {
        require(msg.value >= minFund, "Below minimum fund 10 ether");
        _;
    }

    modifier valWithinRange(uint val, uint low, uint up) {
        require(val < up, "Value higher than max allowed");
        require(val > low, "Value lower than min allowed");
        _;
    }

    modifier paidEnough(uint _price) {
        require(msg.value >= _price, "Value sent below the price");
        _;
    }

    modifier returnAmount(uint _price) {
        uint amountToReturn = msg.value - _price;
        msg.sender.transfer(amountToReturn);
        _;
    }

    modifier airlineRegistered() {
        require(
            flightSuretyData.isRegistered(msg.sender),
            "Airline not registered"
        );
        _;
    }

    modifier airlineFunded() {
        require(
            flightSuretyData.hasFunded(msg.sender),
            "Airline not funded"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address contractAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(contractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view
                            returns(bool) 
    {
        return operational;  // Modify to call data contract's status
    }

    function setOperatingStatus(bool mode) external requireContractOwner {
        require(mode != operational, "Mode already in use");
        operational = mode;
    }

    function getRemainingVotes(address airline) public view returns (uint remainingVotes){
        uint registeredVotes = votes[airline].length;
        uint threshold = flightSuretyData.registeredAirlines().div(2);
        remainingVotes = threshold.sub(registeredVotes);
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address airline 
                            )
                            external
                            requireIsOperational
                            airlineRegistered
                            airlineFunded
                            returns(bool success, uint256 votesTotal)
    {
        // if airlines less than four, then first airline will add
        if (flightSuretyData.registeredAirlines() < 4) {
            require(flightSuretyData.firstAirline() == msg.sender);
            flightSuretyData.registerAirline(airline, msg.sender);
            success = true;
            votesTotal = 0;
        } else {
            //check duplicate votes
            bool isDuplicate = false;
            for (uint i=0; i < votes[airline].length; i++) {
                if (votes[airline][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Caller has been voted");
            votes[airline].push(msg.sender);

            if (getRemainingVotes(airline) == 0) {
                votes[airline] = new address[](0);
                flightSuretyData.registerAirline(airline, msg.sender);
                success = true;
                votesTotal = 0;
            }else{
                success = false;
                votesTotal = getRemainingVotes(airline);
            }
        }
        return (success, votesTotal);
    }
    

    function fund()
    external
    airlineRegistered
    enoughFund
    requireIsOperational
    payable
    {
        flightSuretyData.fund.value(msg.value)(msg.sender);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    uint takeOff,
                                    uint landing,
                                    string calldata flightRef,
                                    uint price,
                                    string calldata from,
                                    string calldata to
                                )
                                external
                                requireIsOperational
                                airlineFunded
    {
        flightSuretyData.registerFlight(
            takeOff,
            landing,
            flightRef,
            price,
            from,
            to,
            msg.sender
        );
        emit FlightRegistered(flightRef, to, landing);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    string memory airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flightSuretyData.changeStatus(flightKey, statusCode);

        emit FlightProcessed(airline, flight, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            string calldata flight,
                            string calldata destination,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = getFlightKey(flight, destination, timestamp);
        // ResponseInfo storage r = oracleResponses[key];
        // r.isOpen = true;
        // r.requester = msg.sender;

        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, flight, destination, timestamp);
    } 

    function buy
    (
        string calldata _flight,
        string calldata _to,
        uint _landing,
        uint amount
    )
    external
    valWithinRange(amount, 0, 1.05 ether)
    paidEnough(flightSuretyData.getFlightPrice(getFlightKey(_flight, _to, _landing)).add(amount))
    returnAmount(flightSuretyData.getFlightPrice(getFlightKey(_flight, _to, _landing)).add(amount))
    requireIsOperational
    payable
    {
        bytes32 flightKey= getFlightKey(_flight, _to, _landing);

        flightSuretyData.buy.value(msg.value)(flightKey, amount.mul(3).div(2), msg.sender);
    }

    function withdraw()
    external
    requireIsOperational
    {
        flightSuretyData.pay(msg.sender);
        emit WithdrawRequest(msg.sender);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(string flight, string destination, uint256 timestamp, uint8 status);

    event OracleReport(string flight, string destination, uint256 timestamp, uint8 status);
    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, string flight, string destination, uint256 timestamp);

    event OracleRegistered(uint8[3] indexes);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });

        emit OracleRegistered(indexes);
    }

    function getIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
    (
        uint8 index,
        string calldata flight,
        string calldata destination,
        uint256 timestamp,
        uint8 statusCode
    )
    external
    {
        require(
            (oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index),
            "Index does not match"
        );


        bytes32 key = getFlightKey(flight, destination, timestamp);
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match");

        oracleResponses[key].responses[statusCode].push(msg.sender);
        emit OracleReport(flight, destination, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length == MIN_RESPONSES) {
            // close responseInfo
            oracleResponses[key].isOpen = false;
            emit FlightStatusInfo(flight, destination, timestamp, statusCode);
            // Handle flight status as appropriate
            processFlightStatus(flight, destination, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            string memory airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

contract FlightSuretyData {
    function registerAirline(address airlineAddress, address originAddress) external;
    function fund(address originAddress) external payable;
    function registerFlight(uint takeOff, uint landing, string calldata flightRef, uint price, string calldata from, string calldata to, address originAddress) external;
    function buy(bytes32 flightKey, uint amount, address originAddress) external payable;
    function pay(address originAddress) external;
    function changeStatus(bytes32 flightKey, uint8 status)  external;
    function getFlightPrice(bytes32 flightKey) external view returns (uint);
    function hasFunded(address airlineAddress) external view returns (bool);
    function isRegistered(address airlineAddress) external view returns (bool);
    function registeredAirlines() external view returns (uint);
    function firstAirline() external view returns (address);
}