// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {MMRProof} from "../src/utils/MMRProof.sol";
import {MMRProofWrapper} from "./mocks/MMRProofWrapper.sol";

contract MMRProofTest is Test {
    using stdJson for string;

    struct Fixture {
        bytes32[] leaves;
        Proof[] proofs;
        bytes32 rootHash;
    }

    struct Proof {
        bytes32[] items;
        uint256 order;
    }

    bytes public fixtureData;
    bytes public fixtureData22ProofItems;
    bytes public fixtureData34ProofItems;

    MMRProofWrapper public wrapper;

    function setUp() public {
        wrapper = new MMRProofWrapper();

        string memory root = vm.projectRoot();
        string memory path_4_proof_items = string.concat(root, "/test/data/mmr-fixture-data-15-leaves.json");
        string memory path_22_proof_items = string.concat(root, "/test/data/mmr-fixture-data-22-proof-items.json");
        string memory path_34_proof_items = string.concat(root, "/test/data/mmr-fixture-data-34-proof-items.json");
        //string memory json = vm.readFile(path);
        fixtureData = vm.readFile(path_4_proof_items).parseRaw("");
        fixtureData22ProofItems = vm.readFile(path_22_proof_items).parseRaw("");
        fixtureData34ProofItems = vm.readFile(path_34_proof_items).parseRaw("");
    }

    function fixture() public view returns (Fixture memory) {
        return abi.decode(fixtureData, (Fixture));
    }

    function fixture22ProofItems() public view returns (Fixture memory) {
        return abi.decode(fixtureData22ProofItems, (Fixture));
    }

    function fixture34ProofItems() public view returns (Fixture memory) {
        return abi.decode(fixtureData34ProofItems, (Fixture));
    }

    function testVerifyLeafProof() public {
        Fixture memory fix = fixture();

        for (uint256 i = 0; i < fix.leaves.length; i++) {
            assertTrue(wrapper.verifyLeafProof(fix.rootHash, fix.leaves[i], fix.proofs[i].items, fix.proofs[i].order));
        }
    }

    function testVerifyLeafProof22ProofItems() public {
        Fixture memory fix = fixture22ProofItems();

        for (uint256 i = 0; i < fix.leaves.length; i++) {
            assertFalse(wrapper.verifyLeafProof(fix.rootHash, fix.leaves[i], fix.proofs[i].items, fix.proofs[i].order));
        }
    }

    function testVerifyLeafProof34ProofItems() public {
        Fixture memory fix = fixture34ProofItems();

        for (uint256 i = 0; i < fix.leaves.length; i++) {
            assertFalse(wrapper.verifyLeafProof(fix.rootHash, fix.leaves[i], fix.proofs[i].items, fix.proofs[i].order));
        }
    }

    function testVerifyLeafProofFailsExceededProofSize() public {
        Fixture memory fix = fixture();

        vm.expectRevert(MMRProof.ProofSizeExceeded.selector);
        wrapper.verifyLeafProof(fix.rootHash, fix.leaves[0], new bytes32[](257), fix.proofs[0].order);
    }
}
