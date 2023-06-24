// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract GameFactory {
    address[] public games;
    UpgradeableBeacon public beacon;

    constructor(address guessTheNumberGameLogic) {
        beacon = new UpgradeableBeacon(guessTheNumberGameLogic);
    }

    function createGame() external {
        BeaconProxy game = new BeaconProxy(address(beacon), "");
        games.push(address(game));
    }

    function getGames() external view returns(address[] memory) {
        return games;
    }
}
