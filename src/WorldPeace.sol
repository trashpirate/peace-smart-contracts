// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721ACore} from "nft-contracts/ERC721ACore.sol";
import {FeeHandler} from "nft-contracts/extensions/FeeHandler.sol";
import {Pausable} from "nft-contracts/utils/Pausable.sol";
import {Whitelist} from "nft-contracts/extensions/Whitelist.sol";
import {Twap} from "twap/Twap.sol";

/// @title WorldPeace
/// @author Nadina Oates
/// @notice Contract implementing ERC721A standard with token and eth fee extension

contract WorldPeace is ERC721ACore, FeeHandler, Pausable, Whitelist {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint32 private constant SECONDS_AGO = 300;
    uint256 private constant PRECISION = 1e18;

    Twap private immutable i_oracle;
    address private immutable i_poolAddress;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor
    /// @param coreConfig configuration for ERC721A
    /// @param feeAddress address for fees
    /// @param tokenAddress erc20 token address used for fees
    /// @param tokenFee minting fee in token
    /// @param ethFee minting fee in native coin
    /// @param merkleRoot merkle root for whitelist
    constructor(
        ERC721ACore.CoreConfig memory coreConfig,
        address feeAddress,
        address tokenAddress,
        uint256 tokenFee,
        uint256 ethFee,
        bytes32 merkleRoot
    ) Whitelist(merkleRoot) ERC721ACore(coreConfig) FeeHandler(tokenAddress, feeAddress, tokenFee, ethFee) {
        i_oracle = Twap(address(0));
        i_poolAddress = address(0);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints NFT for a eth and a token fee
    /// @param quantity number of NFTs to mint
    function mint(uint256 quantity, bytes32[] calldata merkleProof)
        external
        payable
        whenNotPaused
        validQuantity(quantity)
        onlyNotClaimed(msg.sender)
    {
        uint256 fee = getEthFee() * (PRECISION * PRECISION) / i_oracle.calcTwapInEth(i_poolAddress, SECONDS_AGO);
        if (_verifyClaimer(msg.sender, merkleProof)) {
            _setClaimStatus(msg.sender, true);
            _safeMint(msg.sender, quantity);

            uint256 totalFee = (quantity - 1) * fee;
            _chargeTokenFee(totalFee);
        } else {
            _safeMint(msg.sender, quantity);

            uint256 totalFee = quantity * fee;
            _chargeTokenFee(totalFee);
        }
    }

    /// @notice Pauses contract (only owner)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses contract (only owner)
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets minting fee in ERC20 (only owner)
    /// @param fee New fee in ERC20
    function setTokenFee(uint256 fee) external onlyOwner {
        _setTokenFee(fee);
    }

    /// @notice Sets the receiver address for the token/ETH fee (only owner)
    /// @param feeAddress New receiver address for tokens and ETH received through minting
    function setFeeAddress(address feeAddress) external onlyOwner {
        _setFeeAddress(feeAddress);
    }

    /// @notice Sets the merkle root
    /// @param merkleRoot New merkle root
    function setMerkleRoot(bytes32 merkleRoot) external onlyOwner {
        _setMerkleRoot(merkleRoot);
    }
}
