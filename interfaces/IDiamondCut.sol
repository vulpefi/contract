// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IDiamondCut
 * @dev Interface para gerenciar as facetas do Diamond
 *
 * Esta interface define:
 * - Ações possíveis em facetas (Adicionar, Substituir, Remover)
 * - Estrutura para cortes de faceta
 * - Função para modificar o Diamond
 */
interface IDiamondCut {
    /**
     * @dev Ações possíveis ao modificar facetas
     * Add: Adiciona novas funções
     * Replace: Substitui funções existentes
     * Remove: Remove funções
     */
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /**
     * @dev Estrutura que define um corte de faceta
     * @param facetAddress Endereço do contrato da faceta
     * @param action Ação a ser executada
     * @param functionSelectors Lista de seletores de função
     */
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /**
     * @dev Evento emitido quando um corte é realizado
     */
    /**
     * @dev Função principal para modificar o Diamond
     * @param _diamondCut Array de cortes a serem realizados
     * @param _init Endereço do contrato de inicialização
     * @param _calldata Dados para chamada de inicialização
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}
