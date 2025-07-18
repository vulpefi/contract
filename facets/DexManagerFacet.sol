// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title DexManagerFacet
 * @dev Faceta para gerenciamento de DEXs
 * 
 * Esta faceta permite:
 * - Gerenciar DEXs aprovadas
 * - Configurar taxas
 * - Gerenciar recebedores de taxas
 */
contract DexManagerFacet {
    // Eventos
    event DexApprovalUpdated(address indexed dex, bool approved);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event ReferralPercentageUpdated(uint256 oldPercentage, uint256 newPercentage);

    // Estruturas
    struct SwapStorage {
        // Taxa em pontos base (1 = 0.01%, 10 = 0.1%, 100 = 1%)
        uint256 fee;
        // Porcentagem da taxa que vai para o referenciador (3000 = 30%)
        uint256 referralPercentage;
        // Endereço que recebe as taxas
        address feeRecipient;
        // Mapeamento de DEXs aprovadas
        mapping(address => bool) approvedDexes;
    }

    // Constantes
    uint256 private constant MAX_FEE = 50; // 0.5% máximo
    uint256 private constant MAX_REFERRAL_PERCENTAGE = 5000; // 50% máximo
    bytes32 private constant SWAP_STORAGE_POSITION = keccak256("diamond.swap.storage");

    /**
     * @dev Retorna a estrutura de armazenamento da faceta
     */
    function swapStorage() internal pure returns (SwapStorage storage ds) {
        bytes32 position = SWAP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @dev Modificador que restringe acesso ao proprietário
     */
    modifier onlyOwner() {
        require(msg.sender == LibDiamond.contractOwner(), "DexManagerFacet: Apenas o proprietario pode chamar");
        _;
    }

    /**
     * @dev Inicializa a faceta de gerenciamento de DEXs
     * @param _fee Taxa em pontos base (10 = 0.1%)
     * @param _referralPercentage Porcentagem da taxa que vai para o referenciador (3000 = 30%)
     * @param _feeRecipient Endereço que recebe as taxas
     */
    function initializeDexManager(
        uint256 _fee,
        uint256 _referralPercentage,
        address _feeRecipient
    ) external onlyOwner {
        require(_fee <= MAX_FEE, "DexManagerFacet: Taxa muito alta");
        require(_referralPercentage <= MAX_REFERRAL_PERCENTAGE, "DexManagerFacet: Porcentagem de referencia muito alta");
        require(_feeRecipient != address(0), "DexManagerFacet: Endereco invalido");

        SwapStorage storage s = swapStorage();
        s.fee = _fee;
        s.referralPercentage = _referralPercentage;
        s.feeRecipient = _feeRecipient;
    }

    /**
     * @dev Atualiza a aprovação de uma DEX
     * @param _dex Endereço da DEX
     * @param _approved Status de aprovação
     */
    function setDexApproval(address _dex, bool _approved) external onlyOwner {
        require(_dex != address(0), "DexManagerFacet: Endereco invalido");
        
        SwapStorage storage s = swapStorage();
        s.approvedDexes[_dex] = _approved;
        
        emit DexApprovalUpdated(_dex, _approved);
    }

    /**
     * @dev Atualiza a taxa de swap
     * @param _fee Nova taxa em pontos base (10 = 0.1%)
     */
    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "DexManagerFacet: Taxa muito alta");
        
        SwapStorage storage s = swapStorage();
        uint256 oldFee = s.fee;
        s.fee = _fee;
        
        emit FeeUpdated(oldFee, _fee);
    }

    /**
     * @dev Atualiza a porcentagem da taxa que vai para o referenciador
     * @param _referralPercentage Nova porcentagem (3000 = 30%)
     */
    function setReferralPercentage(uint256 _referralPercentage) external onlyOwner {
        require(_referralPercentage <= MAX_REFERRAL_PERCENTAGE, "DexManagerFacet: Porcentagem de referencia muito alta");
        
        SwapStorage storage s = swapStorage();
        uint256 oldPercentage = s.referralPercentage;
        s.referralPercentage = _referralPercentage;
        
        emit ReferralPercentageUpdated(oldPercentage, _referralPercentage);
    }

    /**
     * @dev Atualiza o endereço que recebe as taxas
     * @param _feeRecipient Novo endereço
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != address(0), "DexManagerFacet: Endereco invalido");
        
        SwapStorage storage s = swapStorage();
        address oldRecipient = s.feeRecipient;
        s.feeRecipient = _feeRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, _feeRecipient);
    }

    /**
     * @dev Verifica se uma DEX está aprovada
     * @param _dex Endereço da DEX
     * @return Status de aprovação
     */
    function isDexApproved(address _dex) external view returns (bool) {
        SwapStorage storage s = swapStorage();
        return s.approvedDexes[_dex];
    }

    /**
     * @dev Retorna a taxa atual
     * @return Taxa em pontos base
     */
    function getFee() external view returns (uint256) {
        SwapStorage storage s = swapStorage();
        return s.fee;
    }

    /**
     * @dev Retorna a porcentagem da taxa que vai para o referenciador
     * @return Porcentagem da taxa (3000 = 30%)
     */
    function getReferralPercentage() external view returns (uint256) {
        SwapStorage storage s = swapStorage();
        return s.referralPercentage;
    }

    /**
     * @dev Retorna o endereço que recebe as taxas
     * @return Endereço do recebedor
     */
    function getFeeRecipient() external view returns (address) {
        SwapStorage storage s = swapStorage();
        return s.feeRecipient;
    }
}