// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.21;

import { GovMock } from "./GovMock.sol";

contract IouMock is GovMock {
    constructor(uint256 initialSupply) GovMock(initialSupply) {
    }
}
