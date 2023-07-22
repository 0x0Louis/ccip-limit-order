// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";

import "../src/CCIPLimitOrder.sol";

contract SetTrustedAndTarget is Script, Helper {
    CCIPLimitOrder public ccipLO = CCIPLimitOrder(payable(0x943a837698851f90696e20f009b3bdCB13eE4B27));

    function run(SupportedNetworks network) external {
        if (network != SupportedNetworks.ETHEREUM_SEPOLIA && network != SupportedNetworks.AVALANCHE_FUJI) {
            revert("Invalid network");
        }

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(senderPrivateKey);
        address senderAddress = vm.addr(senderPrivateKey);

        CCIPLimitOrder.Party memory maker = CCIPLimitOrder.Party({
            account: Bytes.toBytes32(senderAddress),
            token: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            amount: 200
        });

        CCIPLimitOrder.Party memory taker =
            CCIPLimitOrder.Party({account: 0, token: 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05, amount: 2000});

        ccipLO.createOrder(maker, taker);

        vm.stopBroadcast();
    }
}
