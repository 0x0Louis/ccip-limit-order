// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EscrowFactory {
    using SafeERC20 for IERC20;

    error EscrowAlreadyExists(bytes32 escrowId);
    error EscrowNotInFundingState();
    error EscrowNotFunded();
    error EscrowAlreadyFundedByParty();

    struct Escrow {
        State state;
    }

    struct EscrowParameter {
        Party partyA;
        Party partyB;
    }

    struct Party {
        address account;
        IERC20 token;
        uint256 amount;
    }

    enum State {
        Invalid,
        Created,
        FundedByA,
        FundedByB,
        Funded
    }

    mapping(bytes32 => Escrow) private _escrows;

    function getEscrow(EscrowParameter calldata parameter) external view returns (Escrow memory) {
        return _escrows[_getEscowId(parameter)];
    }

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory) {
        return _escrows[escrowId];
    }

    function createEscrow(EscrowParameter calldata parameter) external returns (bytes32 escrowId) {
        escrowId = _getEscowId(parameter);

        if (_escrows[escrowId].state != State.Invalid) revert EscrowAlreadyExists(escrowId);

        _escrows[escrowId] = Escrow({state: State.Created});
    }

    function deposit(EscrowParameter calldata parameter, bool depositForPartyA) external returns (bytes32 escrowId) {
        escrowId = _getEscowId(parameter);

        Escrow storage escrow = _escrows[escrowId];

        State state = escrow.state;

        if (state != State.Created) revert EscrowNotInFundingState();
        if (depositForPartyA ? state != State.FundedByB : state != State.FundedByA) revert EscrowAlreadyFundedByParty();

        if (depositForPartyA) {
            parameter.partyA.token.safeTransferFrom(msg.sender, address(this), parameter.partyA.amount);
        } else {
            parameter.partyB.token.safeTransferFrom(msg.sender, address(this), parameter.partyB.amount);
        }

        escrow.state = depositForPartyA
            ? state == State.FundedByB ? State.Funded : State.FundedByA
            : state == State.FundedByA ? State.Funded : State.FundedByB;
    }

    function release(EscrowParameter calldata parameter) external returns (bytes32 escrowId) {
        escrowId = _getEscowId(parameter);

        Escrow storage escrow = _escrows[escrowId];

        if (escrow.state != State.Funded) revert EscrowNotFunded();

        parameter.partyA.token.safeTransfer(parameter.partyA.account, parameter.partyA.amount);
        parameter.partyB.token.safeTransfer(parameter.partyB.account, parameter.partyB.amount);

        escrow.state = State.Invalid;
    }

    function refund(EscrowParameter calldata parameter) external returns (bytes32 escrowId) {
        escrowId = _getEscowId(parameter);

        Escrow storage escrow = _escrows[escrowId];

        State state = escrow.state;

        bool fundedByA = state == State.FundedByA || state == State.Funded;
        bool fundedByB = state == State.FundedByB || state == State.Funded;

        if (fundedByA) parameter.partyA.token.safeTransfer(parameter.partyA.account, parameter.partyA.amount);
        if (fundedByB) parameter.partyB.token.safeTransfer(parameter.partyB.account, parameter.partyB.amount);

        escrow.state = State.Invalid;
    }

    function _getEscowId(EscrowParameter calldata parameter) private pure returns (bytes32) {
        return keccak256(abi.encode(parameter));
    }
}
