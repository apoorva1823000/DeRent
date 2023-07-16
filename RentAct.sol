// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
contract PropertyLeaseContract {
    struct LeaseContract {
        address tenant;
        uint256 rent;
        uint256 securityDeposit;
        uint256 leaseDuration;
        uint256 startDate;
        bool active;
        bool terminated;
        bool frozen;
    }

    mapping(address => LeaseContract) private leaseContracts;
    mapping(address => bool) private authorized;

    address private owner;
    uint256 private inflationRate = 5; // 5% annual inflation rate

    event LeaseContractCreated(address indexed tenant, uint256 rent, uint256 securityDeposit, uint256 leaseDuration);
    event LeaseContractTerminated(address indexed tenant, uint256 refundAmount);
    event RentPaid(address indexed tenant, uint256 amount);
    event AccountFrozen(address indexed tenant);
    event AccountUnfrozen(address indexed tenant);

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "Error: Unauthorized access");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    function setAuthorized(address account, bool isAuthorized) external onlyAuthorized {
        authorized[account] = isAuthorized;
    }

    function createLeaseContract(address tenant, uint256 rent, uint256 leaseDuration) external onlyAuthorized {
        require(tenant != address(0), "Error: Invalid tenant address");
        require(leaseDuration == 11, "Error: Lease duration should be 11 months");

        uint256 securityDeposit = rent * 2;
        LeaseContract storage contractData = leaseContracts[tenant];

        require(!contractData.active && !contractData.terminated, "Error: Lease contract already exists");
        contractData.tenant = tenant;
        contractData.rent = rent;
        contractData.securityDeposit = securityDeposit;
        contractData.leaseDuration = leaseDuration;
        contractData.startDate = block.timestamp;
        contractData.active = true;
        contractData.terminated = false;
        contractData.frozen = false;

        emit LeaseContractCreated(tenant, rent, securityDeposit, leaseDuration);
    }

    function payRent() external payable {
        LeaseContract storage contractData = leaseContracts[msg.sender];

        require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");
        require(msg.value >= contractData.rent, "Error: Insufficient rent amount");

        uint256 rentDifference = msg.value - contractData.rent;
        if (rentDifference > 0) {
            payable(msg.sender).transfer(rentDifference);
        }

        emit RentPaid(msg.sender, contractData.rent);
    }

    function terminateLeaseContract() external onlyAuthorized {
    LeaseContract storage contractData = leaseContracts[msg.sender];

    require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");

    uint256 refundAmount = (contractData.securityDeposit * 75) / 100;
    contractData.active = false;
    contractData.terminated = true;

    // Check if the contract balance is sufficient for the refund
    require(address(this).balance >= refundAmount, "Error: Insufficient contract balance for refund");

    // Transfer the refund amount to the tenant
    payable(msg.sender).transfer(refundAmount);

    emit LeaseContractTerminated(msg.sender, refundAmount);
}


    function checkRentDue(address tenant) external view returns (uint256) {
        LeaseContract storage contractData = leaseContracts[tenant];

        require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");

        uint256 leaseDuration = contractData.leaseDuration;
        uint256 startDate = contractData.startDate;
        uint256 currentTimestamp = block.timestamp;
        uint256 rentDue = contractData.rent;

        for (uint256 i = 0; i < leaseDuration; i++) {
            rentDue = (rentDue * (100 + inflationRate)) / 100;

            if (startDate + (i + 1) * 30 days <= currentTimestamp) {
                break;
            }
        }

        return rentDue;
    }

    function checkSecurityDeposit(address tenant) external view returns (uint256) {
        LeaseContract storage contractData = leaseContracts[tenant];

        require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");

        return contractData.securityDeposit;
    }

    function checkContractStatus(address tenant) external view returns (bool) {
        LeaseContract storage contractData = leaseContracts[tenant];

        return contractData.active && !contractData.terminated;
    }

    function freezeAccount(address tenant) external onlyAuthorized {
        LeaseContract storage contractData = leaseContracts[tenant];

        require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");

        contractData.frozen = true;

        emit AccountFrozen(tenant);
    }

    function unfreezeAccount(address tenant) external onlyAuthorized {
        LeaseContract storage contractData = leaseContracts[tenant];

        require(contractData.active && !contractData.terminated, "Error: Invalid lease contract");

        contractData.frozen = false;

        emit AccountUnfrozen(tenant);
    }

    function getLeaseContractDetails(address tenant) external view onlyAuthorized returns (LeaseContract memory) {
        return leaseContracts[tenant];
    }
}