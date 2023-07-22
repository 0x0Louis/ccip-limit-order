// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import "../src/CCIPLimitOrder.sol";

contract DeployCCIPLO is Script, Helper {
    function run(SupportedNetworks network) external returns (address ccipLO) {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        (address router, address link,, uint64 chainId) = getConfigFromNetwork(network);

        vm.startBroadcast(senderPrivateKey);
        address senderAddress = vm.addr(senderPrivateKey);

        ccipLO = address(new CCIPLimitOrder(router, chainId, link, 0, 0, senderAddress));

        vm.stopBroadcast();
    }
}
