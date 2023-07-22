// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable2Step} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {IRouterClient} from "ccip/contracts/interfaces/IRouterClient.sol";
import {CCIPReceiver, Client} from "ccip/contracts/applications/CCIPReceiver.sol";
import {SafeERC20, IERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract CCIPBase is Ownable2Step, CCIPReceiver {
    error SameTargetContract(bytes32 targetContract);
    error SameTrustedTokenStatus(bool status);

    mapping(uint64 => bytes32) private _targetContracts;
    mapping(address => bool) private _trustedTokens;

    event TargetContractSet(uint64 indexed chainSelector, bytes32 indexed targetContract);
    event TrustedTokenSet(address indexed token, bool trusted);

    constructor(address router) CCIPReceiver(router) {}

    function getTargetContract(uint64 chainSelector) external view returns (bytes32 targetContract) {
        return _getTargetContract(chainSelector);
    }

    function isTrustedToken(address token) external view returns (bool trusted) {
        return _isTrustedToken(token);
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

    function _getTargetContract(uint64 chainSelector) internal view returns (bytes32 targetContract) {
        targetContract = _targetContracts[chainSelector];
    }

    function _isTrustedToken(address token) internal view returns (bool trusted) {
        return _trustedTokens[token];
    }
}
