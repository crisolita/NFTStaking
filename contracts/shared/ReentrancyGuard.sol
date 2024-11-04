// SPDX-License-Identifier: MIT
pragma solidity>= 0.8.23;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";

// From OpenZeppellin: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    error ReentrancyGuardError();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        if (LibAppStorage.diamondStorage().reentrancyStatus == _ENTERED)
            revert ReentrancyGuardError();

        LibAppStorage.diamondStorage().reentrancyStatus = _ENTERED;

        _;

        LibAppStorage.diamondStorage().reentrancyStatus = _NOT_ENTERED;
    }
}