// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IERC173
 * @dev Interface para gerenciamento de propriedade do contrato
 * 
 * Esta interface implementa o padrão ERC-173 que define:
 * - Funções para gerenciar a propriedade do contrato
 * - Eventos para rastrear mudanças de propriedade
 */
interface IERC173 {
    /**
     * @dev Evento emitido quando a propriedade do contrato é transferida
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Retorna o endereço do proprietário atual
     */
    function owner() external view returns (address owner_);

    /**
     * @dev Transfere a propriedade do contrato para um novo endereço
     * @param _newOwner Endereço do novo proprietário
     */
    function transferOwnership(address _newOwner) external;
}