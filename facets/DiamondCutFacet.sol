// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

/**
 * @title DiamondCutFacet
 * @dev Faceta para gerenciar atualizações do Diamond
 * 
 * Esta faceta permite:
 * - Adicionar novas facetas
 * - Remover facetas existentes
 * - Substituir facetas
 */
contract DiamondCutFacet is IDiamondCut {
    /**
     * @dev Executa um corte no Diamond
     * @param _diamondCut Array de cortes a serem realizados
     * @param _init Endereço do contrato de inicialização
     * @param _calldata Dados para chamada de inicialização
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {
        require(msg.sender == LibDiamond.contractOwner(), "Must be contract owner");
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}


