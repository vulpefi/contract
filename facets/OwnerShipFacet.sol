// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC173 } from "../interfaces/IERC173.sol";

contract OwnershipFacet is IERC173 {
    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function transferOwnership(address _newOwner) external override {
        require(msg.sender == LibDiamond.contractOwner(), "OwnershipFacet: Apenas owner");
        require(_newOwner != address(0), "OwnershipFacet: Owner invalido");
        
        address previousOwner = LibDiamond.contractOwner();
        LibDiamond.setContractOwner(_newOwner);
        
        emit OwnershipTransferred(previousOwner, _newOwner);
    }
}