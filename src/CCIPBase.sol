// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver, Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Bytes} from "./library/Bytes.sol";

abstract contract CCIPBase is Ownable2Step, CCIPReceiver {
    using SafeERC20 for IERC20;

    error SameTargetContract(bytes32 targetContract);
    error SameTrustedTokenStatus(bool status);
    error UntrustedToken(address token);

    event TargetContractSet(uint64 indexed chainSelector, bytes32 indexed targetContract);
    event TrustedTokenSet(address indexed token, bool trusted);
    event MessageSent(bytes32 indexed messageId);
    event FeeTokenSet(address feeToken);

    address private _feeToken;

    mapping(uint64 => bytes32) private _targetContracts;
    mapping(address => bool) private _trustedTokens;

    constructor(address router) CCIPReceiver(router) {}

    function getTargetContract(uint64 chainSelector) external view returns (bytes32 targetContract) {
        return _getTargetContract(chainSelector);
    }

    function isTrustedToken(address token) external view returns (bool trusted) {
        return _isTrustedToken(token);
    }

    function getFeeToken() external view returns (address feeToken) {
        return _feeToken;
    }

    function setTargetContract(uint64 chainSelector, bytes32 targetContract) external onlyOwner {
        if (_targetContracts[chainSelector] == targetContract) revert SameTargetContract(targetContract);

        _targetContracts[chainSelector] = targetContract;

        emit TargetContractSet(chainSelector, targetContract);
    }

    function setTrustedToken(address token, bool trusted) external onlyOwner {
        if (_trustedTokens[token] == trusted) revert SameTrustedTokenStatus(trusted);

        _trustedTokens[token] = trusted;
        IERC20(token).approve(getRouter(), trusted ? type(uint256).max : 0);

        emit TrustedTokenSet(token, trusted);
    }

    function setFeeToken(address feeToken) external onlyOwner {
        _feeToken = feeToken;

        emit FeeTokenSet(feeToken);
    }

    function _getTargetContract(uint64 chainSelector) internal view returns (bytes32 targetContract) {
        targetContract = _targetContracts[chainSelector];
    }

    function _isTrustedToken(address token) internal view returns (bool trusted) {
        return _trustedTokens[token];
    }

    function _ccipSend(
        uint64 destChainSelector,
        bytes32 receiver,
        bytes memory data,
        Client.EVMTokenAmount[] memory tokenAmounts,
        uint256 maxFee,
        uint256 gasLimit
    ) internal {
        address feeToken = _feeToken;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: Bytes.toBytes(receiver),
            data: data,
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: gasLimit, strict: false})),
            feeToken: feeToken
        });

        _transferTokens(tokenAmounts, msg.sender);

        uint256 fee = IRouterClient(getRouter()).getFee(destChainSelector, message);

        _handleFee(feeToken, maxFee, fee);

        bool isFeeNative = feeToken == address(0);

        bytes32 messageId =
            IRouterClient(getRouter()).ccipSend{value: isFeeNative ? fee : 0}(destChainSelector, message);

        emit MessageSent(messageId);
    }

    function _transferTokens(Client.EVMTokenAmount[] memory tokenAmounts, address from) internal {
        for (uint256 i; i < tokenAmounts.length; ++i) {
            address token = tokenAmounts[i].token;

            if (!_trustedTokens[token]) revert UntrustedToken(token);

            IERC20(token).safeTransferFrom(from, address(this), tokenAmounts[i].amount);
        }
    }

    function _handleFee(address feeToken, uint256 maxFee, uint256 fee) internal view virtual {}
}
