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

        if (network == SupportedNetworks.ETHEREUM_SEPOLIA) {
            ccipLO.setTrustedToken(linkEthereumSepolia, true);
            ccipLO.setTrustedToken(ccipBnMEthereumSepolia, true);

            ccipLO.setTargetContract(chainIdAvalancheFuji, Bytes.toBytes32(address(ccipLO)));
        } else if (network == SupportedNetworks.AVALANCHE_FUJI) {
            ccipLO.setTrustedToken(linkAvalancheFuji, true);
            ccipLO.setTrustedToken(ccipBnMAvalancheFuji, true);

            ccipLO.setTargetContract(chainIdEthereumSepolia, Bytes.toBytes32(address(ccipLO)));
        }

        vm.stopBroadcast();
    }
}
