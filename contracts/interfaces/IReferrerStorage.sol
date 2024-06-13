// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


interface IReferrerStorage {
    event ReferrerSet(
        address sender,
        address referrer,
        uint256 blockTime
    );
    function referrers(address _sender) external view returns(address referrer);
    function setReferrer(address _referrer) external;
    function getReferrers(address user) external view returns(address referrer,address upReferrer);
}
