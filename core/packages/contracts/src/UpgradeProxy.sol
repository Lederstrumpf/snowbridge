// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2023 Snowfork <hello@snowfork.com>
pragma solidity 0.8.20;

import {AccessControl} from "openzeppelin/access/AccessControl.sol";
import {UpgradeTask} from "./UpgradeTask.sol";
import {ParaID} from "./Types.sol";
import {Gateway} from "./Gateway.sol";
import {IRecipient} from "./IRecipient.sol";
import {Registry} from "./Registry.sol";
import {BeefyClient, ValidatorProof} from "./BeefyClient.sol";

contract UpgradeProxy is Gateway {
    // TODO: add upgrade nonce

    struct Message {
        Action action;
        bytes payload;
    }

    struct FallbackGovernance {
        // TODO: maybe add action - as a safety net
        // Action action;
        bytes payload;
        uint256[] calldata bitfield;
        ValidatorProof[] calldata proofs;
        // TODO: add check against current block height, or add some other nonce to prevent replay attacks etc.
    }

    enum Action {Upgrade UpgradeFallback}

    struct UpgradePayload {
        address task;
    }

    error InvalidMessage();
    error FallbackSignatureInvalid();
    error UpgradeFailed();

    // Parachain ID of BridgeHub
    ParaID public immutable bridgeHubParaID;

    constructor(Registry registry, ParaID _bridgeHubParaID) Gateway(registry) {
        bridgeHubParaID = _bridgeHubParaID;
    }

    function handle(ParaID origin, bytes calldata message) external override onlyRole(SENDER_ROLE) {
        ensureOrigin(origin, bridgeHubParaID);

        Message memory decoded = abi.decode(message, (Message));
        if (decoded.action != Action.Upgrade) {
            revert InvalidMessage();
        }

        UpgradePayload memory payload = abi.decode(decoded.payload, (UpgradePayload));

        (bool success,) = payload.task.delegatecall(abi.encodeCall(UpgradeTask.run, ()));
        if (!success) {
            revert UpgradeFailed();
        }
    }

    function handleFallback(bytes calldata message) {
        Message memory decoded = abi.decode(message, (Message));
        // if (decoded.action != Action.UpgradeFallback) {
        //     revert InvalidMessage();
        // }

        uint256[] memory bitfield = abi.decode(decoded.payload, (uint256[]));
        ValidatorProof[] memory proofs = abi.decode(decoded.proofs, (ValidatorProof[]));

        // TODO: proper arithmetic
        if countSetBits(bitfield) < bitfield.length * 2/3 {
            revert FallbackSignatureInvalid();
        }

        BeefyClient beefyClientInstance = BeefyClient(lookupContract(keccak256("BeefyClient")));
        BeefyClient.ValidatorSet memory currentValidatorSet = beefyClientInstance.currentValidatorSet;

        bytes32 hashedPayload = keccak256(decoded.payload);

        for (uint256 i = 0; i < proofs.length; i++) {
            ValidatorProof calldata proof = proofs[i];

            // Check that validator is in bitfield
            if (!Bitfield.isSet(bitfield, proof.index)) {
                revert InvalidValidatorProof();
            }

            // Check that validator is actually in a validator set
            if (!isValidatorInSet(currentValidatorSet, proof.account, proof.index, proof.proof)) {
                revert InvalidValidatorProof();
            }

            // Check that validator signed the commitment
            if (ECDSA.recover(hashedPayload, proof.v, proof.r, proof.s) != proof.account) {
                revert InvalidSignature();
            }

            // Ensure no validator can appear more than once in bitfield
            Bitfield.unset(bitfield, proof.index);

            unchecked {
                i++;
            }
        }

        UpgradePayload memory payload = abi.decode(decoded.payload, (UpgradePayload));

        (bool success,) = payload.task.delegatecall(abi.encodeCall(UpgradeTask.run, ()));
        if (!success) {
            revert UpgradeFailed();
        }
    }
}
