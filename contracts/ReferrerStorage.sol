// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./interfaces/IReferrerStorage.sol";

contract ReferrerStorage is IReferrerStorage {
    // user => referrer
    mapping(address => address) public override referrers;

    function setReferrer(address _referrer) public {
        require(msg.sender != _referrer, "not user self");
        require(referrers[msg.sender] == address(0), "User invited");
        referrers[msg.sender] = _referrer;
        emit ReferrerSet(msg.sender, _referrer, block.timestamp);
    }

    function getReferrers(address user) public view returns(address referrer,address upReferrer){
        if (referrers[user] != address(0)){
            referrer = referrers[user];
        }
        if (referrer != address(0)){
            upReferrer = referrers[referrer];
        }
        return (referrer, upReferrer);
    }
}
