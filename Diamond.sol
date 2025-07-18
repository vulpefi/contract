// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "./libraries/LibDiamond.sol";
import { IDiamondCut } from "./interfaces/IDiamondCut.sol";

/**
 * @title Diamond
 * @dev Contrato principal que implementa o padrão Diamond EIP-2535
 * 
 * O padrão Diamond permite que um contrato seja dividido em múltiplos contratos menores (facetas)
 * para melhor organização e possibilidade de atualizações parciais.
 */
contract Diamond {
    /**
     * @dev Construtor que inicializa o contrato Diamond
     * @param _contractOwner Endereço do proprietário do contrato
     * @param _diamondCutFacet Endereço da faceta que implementa a função diamondCut
     * 
     * O construtor realiza as seguintes operações:
     * 1. Define o proprietário do contrato
     * 2. Adiciona a função diamondCut da primeira faceta
     */
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        require(_contractOwner != address(0), "Diamond: owner cannot be zero address");
        require(_diamondCutFacet != address(0), "Diamond: DiamondCutFacet cannot be zero address");
        
      LibDiamond.setContractOwner(_contractOwner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibDiamond.diamondCut(cut, address(0), "");
    }

    /**
     * @dev Função fallback que encaminha as chamadas para as facetas apropriadas
     * 
     * Esta função:
     * 1. Identifica qual faceta implementa a função chamada
     * 2. Executa a função usando delegatecall
     * 3. Retorna o resultado ou reverte em caso de erro
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        
        assembly {
            ds.slot := position
        }
        
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Função receive que permite ao contrato receber ETH
     */
    receive() external payable {}
}