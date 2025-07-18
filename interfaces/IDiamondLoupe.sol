// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IDiamondLoupe
 * @dev Interface para inspecionar o estado do Diamond
 * 
 * Esta interface permite:
 * - Consultar todas as facetas e suas funções
 * - Encontrar qual faceta implementa uma função específica
 * - Listar todos os endereços de facetas
 */
interface IDiamondLoupe {
    /**
     * @dev Estrutura que representa uma faceta e suas funções
     */
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /**
     * @dev Retorna todas as facetas e seus seletores de função
     */
    function facets() external view returns (Facet[] memory facets_);

    /**
     * @dev Retorna todos os seletores de função de uma faceta específica
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /**
     * @dev Retorna todos os endereços das facetas
     */
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /**
     * @dev Retorna o endereço da faceta que implementa um determinado seletor
     */
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}