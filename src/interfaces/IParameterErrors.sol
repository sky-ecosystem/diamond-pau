// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title Interface defining errors for Registry Parameters library.
 * @dev   This interface should be inherited by any contract that uses the Registry Parameters
 *        library in order to expose the errors that may be thrown by the library.
 */
interface IParameterErrors {

    /// @notice Thrown when the parameter is out of type bounds.
    error ParameterOutOfTypeBounds();

}
