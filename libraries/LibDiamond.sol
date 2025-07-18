// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IDiamondCut } from "../interfaces/IDiamondCut.sol";

/**
 * @title LibDiamond
 * @dev Biblioteca que implementa a lógica principal do padrão Diamond
 */
library LibDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    /**
     * @dev Estrutura que mapeia um endereço de faceta e sua posição
     */
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition;
    }

    /**
     * @dev Estrutura que armazena os seletores de uma faceta
     */
    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition;
    }

    /**
     * @dev Estrutura principal de armazenamento do Diamond
     */
    struct DiamondStorage {
        // Mapeamento de seletor de função para endereço da faceta e posição
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // Mapeamento de faceta para seus seletores de função
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // Lista de endereços das facetas
        address[] facetAddresses;
        // Mapeamento de ID de interface para suporte
        mapping(bytes4 => bool) supportedInterfaces;
        // Proprietário do contrato
        address contractOwner;
    }

    /**
     * @dev Eventos emitidos pela biblioteca
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    /**
     * @dev Retorna o storage do Diamond
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @dev Define o proprietário do contrato
     */
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @dev Retorna o proprietário do contrato
     */
    function contractOwner() internal view returns (address) {
        return diamondStorage().contractOwner;
    }

    /**
     * @dev Modificador que restringe acesso ao proprietário
     */
    modifier onlyOwner() {
        require(msg.sender == contractOwner(), "LibDiamond: Must be contract owner");
        _;
    }

    /**
     * @dev Executa um corte no Diamond
     */
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert("LibDiamond: Invalid FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    /**
     * @dev Adiciona novas funções ao Diamond
     */
    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "LibDiamond: Add facet can't be address(0)");
        require(_functionSelectors.length > 0, "LibDiamond: No selectors to add");
        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        
        // Adiciona nova faceta se necessário
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamond: Can't add function that already exists");
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @dev Remove funções do Diamond
     */
    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_functionSelectors.length > 0, "LibDiamond: No selectors to remove");
        DiamondStorage storage ds = diamondStorage();
        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            FacetAddressAndPosition memory oldFacetAddressAndPosition = ds.selectorToFacetAndPosition[selector];
            require(oldFacetAddressAndPosition.facetAddress != address(0), "LibDiamond: Can't remove function that doesn't exist");
            removeFunction(ds, oldFacetAddressAndPosition.facetAddress, selector);
        }
    }

    /**
     * @dev Substitui funções no Diamond
     */
    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        require(_facetAddress != address(0), "LibDiamond: Replace facet can't be address(0)");
        require(_functionSelectors.length > 0, "LibDiamond: No selectors to replace");
        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        // Adiciona nova faceta se necessário
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamond: Can't replace function with same function");
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @dev Adiciona uma nova faceta ao Diamond
     */
    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamond: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    /**
     * @dev Adiciona uma função a uma faceta
     */
    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
    }

    /**
     * @dev Remove uma função de uma faceta
     */
    function removeFunction(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        require(_facetAddress != address(0), "LibDiamond: Can't remove function that doesn't exist");
        
        // Obtém índice do seletor
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        
        // Se não for o último seletor, move o último para a posição do removido
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        
        // Remove o último seletor
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // Remove a faceta se não tiver mais funções
        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
        }
    }

    /**
     * @dev Inicializa um corte no Diamond
     */
    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            require(_calldata.length == 0, "LibDiamond: _init is address(0) but _calldata is not empty");
        } else {
            require(_calldata.length > 0, "LibDiamond: _calldata is empty but _init is not address(0)");
            if (_init != address(this)) {
                enforceHasContractCode(_init, "LibDiamond: _init address has no code");
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                if (error.length > 0) {
                    // Propaga o erro
                    assembly {
                        let ptr := add(error, 0x20)
                        revert(ptr, mload(error))
                    }
                } else {
                    revert("LibDiamond: _init function reverted");
                }
            }
        }
    }

    /**
     * @dev Verifica se um endereço contém código
     */
    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}