pragma solidity >=0.5.0 <0.6.0;

// Copyright 2019 OpenST Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import "../consensus/CoconsensusModule.sol";
import "../consensus/CoconsensusI.sol";
import "../consensus-gateway/ConsensusGatewayBase.sol";
import "../consensus-gateway/ERC20GatewayBase.sol";
import "../message-bus/MessageBus.sol";
import "../message-bus/StateRootI.sol";
import "../proxies/MasterCopyNonUpgradable.sol";
import "../utility-token/UtilityTokenInterface.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract ConsensusCogateway is MasterCopyNonUpgradable, MessageBus, ConsensusGatewayBase, ERC20GatewayBase, CoconsensusModule {

    /* Usings */

    using SafeMath for uint256;


    /* Constants */

    /* Storage offset of message outbox. */
    uint8 constant public OUTBOX_OFFSET = uint8(1);

    /* Storage offset of message inbox. */
    uint8 constant public INBOX_OFFSET = uint8(4);


    /* External functions */

    /**
     * @notice It sets up consensus cogateway. It can only be called once.
     *
     * @param _metachainId Metachain id of a metablock.
     * @param _coconsensus Address of Coconsensus contract.
     * @param _utMOST Address of most contract at auxiliary chain.
     * @param _consensusGateway Address of most contract at auxiliary chain.
     * @param _outboxStorageIndex Outbox Storage index of ConsensusGateway.
     * @param _maxStorageRootItems Max storage roots to be stored.
     * @param _metablockHeight Height of the metablock.
     */
    function setup(
        bytes32 _metachainId,
        address _coconsensus,
        ERC20I _utMOST,
        address _consensusGateway,
        uint8 _outboxStorageIndex,
        uint256 _maxStorageRootItems,
        uint256 _metablockHeight
    )
        external
    {
        /*
         * Setup method can only be called once because of the check for
         * outboundMessageIdentifier in setupMessageOutbox method of
         * MessageOutbox contract.
         */

        ConsensusGatewayBase.setup(_utMOST, _metablockHeight);

        MessageOutbox.setupMessageOutbox(
            _metachainId,
            _consensusGateway
        );

        address anchor = CoconsensusI(_coconsensus).getAnchor(_metachainId);

        require(
            anchor != address(0),
            "Anchor address must not be 0."
        );

        MessageInbox.setupMessageInbox(
            _metachainId,
            _consensusGateway,
            _outboxStorageIndex,
            StateRootI(anchor),
            _maxStorageRootItems
        );
    }

    /**
     * @notice It allows to withdraw utMOST tokens. Withdrawer needs to approve
     *         ConsensusCoGateway contract for amount to be withdrawn.
     *
     * @dev Function requires :
     *          - Amount must not be 0.
     *          - Beneficiary must not be 0.
     *          - Amount must be greater than gas price and gas limit.
     *
     * @param _amount Amount of tokens to be redeemed.
     * @param _beneficiary The address in the origin chain where the value
     *                     where the tokens will be released.
     * @param _feeGasPrice Fee gas price at which reward will be calculated.
     * @param _feeGasLimit Fee gas limit at which reward will be calculated.
     *
     * @return messageHash_ Message hash.
     */
    function withdraw(
        uint256 _amount,
        address _beneficiary,
        uint256 _feeGasPrice,
        uint256 _feeGasLimit
    )
        external
        returns(bytes32 messageHash_)
    {
        require(
            _amount != 0,
            "Withdrawal amount should be greater than 0."
        );
        require(
            _beneficiary != address(0),
            "Beneficiary address must not be 0."
        );
        require(
            _amount > _feeGasPrice.mul(_feeGasLimit),
            "Withdrawal amount should be greater than max reward."
        );

        bytes32 hashWithdrawIntent = hashWithdrawIntent(
            _amount,
            _beneficiary
        );

        uint256 nonce = nonces[msg.sender];
        nonces[msg.sender] = nonce.add(1);

        messageHash_ = MessageOutbox.declareMessage(
            hashWithdrawIntent,
            nonce,
            _feeGasPrice,
            _feeGasLimit,
            msg.sender
        );

        require(
            UtilityTokenInterface(address(most)).burnFrom(msg.sender, _amount),
            "utMOST burnFrom must succeed."
        );
    }
}
