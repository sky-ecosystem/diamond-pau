// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.34;

import { IALMProxy }   from "../interfaces/IALMProxy.sol";
import { ICCTPFacet }  from "../interfaces/facets/ICCTPFacet.sol";
import { IParameters } from "../interfaces/IParameters.sol";
import { IRateLimits } from "../interfaces/IRateLimits.sol";

import { FacetBase }                                   from "./FacetBase.sol";
import { combineKeyComponents, uint256ToKeyComponent } from "../ParameterKeys.sol";
import { ParameterHelpers }                            from "../ParameterHelpers.sol";
import { makeUint32Key }                               from "../RateLimitHelpers.sol";

interface ICCTPLike {

    function depositForBurn(
        uint256 amount,
        uint32  destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32  minFinalityThreshold
    ) external;

    function localMinter() external view returns (address);

}

interface ICCTPTokenMinterLike {

    function burnLimitsPerMessage(address) external view returns (uint256);

}

interface IERC20Like {

    function approve(address spender, uint256 amount) external returns (bool);

}

// NOTE: This contract makes the assumption that the token is USDC.
contract CCTPFacet is ICCTPFacet, FacetBase {

    /**********************************************************************************************/
    /*** Declarations and Constructor                                                           ***/
    /**********************************************************************************************/

    string public constant CCTP_MAX_FEE_CAP_KEY  = "sky.pau.cctp.cctpMaxFeeCap";
    string public constant MINT_RECIPIENT_PREFIX = "sky.pau.cctp.mintRecipient";

    bytes32 public constant LIMIT_TO_CCTP   = keccak256("LIMIT_USDC_TO_CCTP");
    bytes32 public constant LIMIT_TO_DOMAIN = keccak256("LIMIT_USDC_TO_DOMAIN");

    bytes32 public constant DESTINATION_CALLER     = 0;      // 0 means anyone can relay
    uint256 public constant MAX_FEE                = 0;      // 0 for standard burns (no fast burn fee)
    uint32  public constant MAX_FINALITY_THRESHOLD = 2_000;  // 2_000 for standard (finalized) messages

    address public immutable cctp;
    address public immutable usdc;

    constructor(address cctp_, address usdc_) {
        cctp = cctp_;
        usdc = usdc_;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setCCTPMaxFeeCap(uint256 maxFeeCap)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IParameters(_getControllerStorage().parameters).set(
            CCTP_MAX_FEE_CAP_KEY,
            ParameterHelpers.fromUint256(maxFeeCap)
        );

        emit CCTPMaxFeeCapSet(maxFeeCap);
    }

    function setMintRecipient(uint32 destinationDomain, bytes32 recipient)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IParameters(_getControllerStorage().parameters).set(
            _getMintRecipientKey(destinationDomain),
            recipient
        );

        emit MintRecipientSet(destinationDomain, recipient);
    }

    /**********************************************************************************************/
    /*** External functions                                                                     ***/
    /**********************************************************************************************/

    function transfer(uint256 usdcAmount, uint32 destinationDomain)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _transfer(usdcAmount, MAX_FEE, destinationDomain);
    }

    function transfer(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain)
        external
        nonReentrant
        onlyRole(RELAYER_ROLE)
    {
        _transfer(usdcAmount, maxFee, destinationDomain);
    }

    /**********************************************************************************************/
    /*** View functions                                                                         ***/
    /**********************************************************************************************/

    function cctpMaxFeeCap() external view returns (uint256) {
        return ParameterHelpers.toUint256(
            IParameters(_getControllerStorage().parameters).get(CCTP_MAX_FEE_CAP_KEY)
        );
    }

    function mintRecipients(uint32 destinationDomain) external view returns (bytes32) {
        return IParameters(_getControllerStorage().parameters).get(
            _getMintRecipientKey(destinationDomain)
        );
    }

    /**********************************************************************************************/
    /*** Internal functions                                                                     ***/
    /**********************************************************************************************/

    function _transfer(uint256 usdcAmount, uint256 maxFee, uint32 destinationDomain) internal {
        ControllerStorage storage $ = _getControllerStorage();

        _decreaseRateLimit($.rateLimits, LIMIT_TO_CCTP, usdcAmount);

        _decreaseRateLimit(
            $.rateLimits,
            makeUint32Key(LIMIT_TO_DOMAIN, destinationDomain),
            usdcAmount
        );

        uint256 _cctpMaxFeeCap = ParameterHelpers.toUint256(
            IParameters($.parameters).get(CCTP_MAX_FEE_CAP_KEY)
        );

        bytes32 recipient = IParameters($.parameters).get(
            _getMintRecipientKey(destinationDomain)
        );

        require(recipient != 0,           "CCTPFacet/domain-not-configured");
        require(maxFee <= _cctpMaxFeeCap, "CCTPFacet/max-fee-exceeds-cap");

        // Approve USDC to CCTP from the proxy (assumes the proxy has enough USDC).
        _approve(usdc, $.proxy, cctp, usdcAmount);

        // If amount is larger than limit it must be split into multiple calls.
        uint256 burnLimit =
            ICCTPTokenMinterLike(ICCTPLike(cctp).localMinter()).burnLimitsPerMessage(usdc);

        while (usdcAmount > 0) {
            uint256 amount = usdcAmount > burnLimit ? burnLimit : usdcAmount;

            // NOTE: When amount is split into chunks, the last chunk may be
            //       smaller than maxFee causing a revert.
            require(maxFee < amount, "CCTPFacet/incorrect-max-fee");

            _initiateTransfer(
                $.proxy,
                amount,
                maxFee,
                recipient,
                destinationDomain
            );

            usdcAmount -= amount;
        }
    }

    // NOTE: As USDC is the only asset transferred using CCTP, `ApproveLib` is unnecessary.
    function _approve(address token, address proxy, address spender, uint256 amount) internal {
        IALMProxy(proxy).doCall(token, abi.encodeCall(IERC20Like.approve, (spender, amount)));
    }

    function _initiateTransfer(
        address proxy,
        uint256 usdcAmount,
        uint256 maxFee,
        bytes32 mintRecipient,
        uint32  destinationDomain
    )
        internal
    {
        IALMProxy(proxy).doCall(
            cctp,
            abi.encodeCall(
                ICCTPLike.depositForBurn,
                (
                    usdcAmount,
                    destinationDomain,
                    mintRecipient,
                    usdc,
                    DESTINATION_CALLER,
                    maxFee,
                    MAX_FINALITY_THRESHOLD
                )
            )
        );

        emit CCTPTransferInitiated(destinationDomain, mintRecipient, usdcAmount);
    }

    function _getMintRecipientKey(uint32 destinationDomain) internal pure returns (string memory) {
        return combineKeyComponents(
            MINT_RECIPIENT_PREFIX,
            uint256ToKeyComponent(uint256(destinationDomain))
        );
    }

    /**********************************************************************************************/
    /*** Rate Limit helper functions                                                            ***/
    /**********************************************************************************************/

    function _decreaseRateLimit(address rateLimits, bytes32 key, uint256 amount) internal {
        IRateLimits(rateLimits).triggerRateLimitDecrease(key, amount);
    }

}
