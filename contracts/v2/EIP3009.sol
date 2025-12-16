/**
 * Copyright 2023 Circle Internet Group, Inc. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity 0.6.12;

import { AbstractFiatTokenV2 } from "./AbstractFiatTokenV2.sol";
import { EIP712Domain } from "./EIP712Domain.sol";
import { SignatureChecker } from "../util/SignatureChecker.sol";
import { MessageHashUtils } from "../util/MessageHashUtils.sol";

/**
 * @title EIP-3009 - Gas 抽象转账
 * @notice 提供免 gas 的代币转账功能
 * @dev 实现 EIP-3009 标准，允许用户通过链下签名完成转账
 *
 * EIP-3009 vs EIP-2612：
 * - EIP-2612: 授权（approve），需要两步（授权+转账）
 * - EIP-3009: 直接转账，只需一步
 *
 * 核心功能：
 * 1. transferWithAuthorization: 通用的授权转账
 * 2. receiveWithAuthorization: 收款方提交的授权转账（防抢跑）
 * 3. cancelAuthorization: 取消未使用的授权
 *
 * 使用场景：
 * - P2P 转账：发送方签名，接收方提交（接收方付 gas）
 * - 商家收款：客户签名授权，商家代为提交
 * - 批量支付：员工签名，公司财务统一提交
 *
 * Nonce 机制：
 * - 与 EIP-2612 不同，这里使用随机 bytes32 作为 nonce
 * - 不是顺序递增，而是随机生成
 * - 优势：可以并行签署多笔交易，不受顺序限制
 * - 每个 nonce 只能使用一次
 *
 * 时间窗口：
 * - validAfter: 授权生效时间（可以设置未来时间）
 * - validBefore: 授权过期时间
 * - 允许设置有效期，增加安全性
 *
 * 安全特性：
 * - 防重放：每个 nonce 只能使用一次
 * - 时间限制：可设置有效时间窗口
 * - 可取消：未使用的授权可以取消
 * - 防抢跑：receiveWithAuthorization 确保只有收款方能提交
 */
abstract contract EIP3009 is AbstractFiatTokenV2, EIP712Domain {
    // TransferWithAuthorization 消息的类型哈希
    // keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32
        public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = 0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    // ReceiveWithAuthorization 消息的类型哈希
    // keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32
        public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = 0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    // CancelAuthorization 消息的类型哈希
    // keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")
    bytes32
        public constant CANCEL_AUTHORIZATION_TYPEHASH = 0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

    /**
     * @dev 授权状态映射
     * 授权者地址 => nonce => 是否已使用（true = 已使用或已取消）
     * 注意：使用 bytes32 作为 nonce，而不是递增的数字
     */
    mapping(address => mapping(bytes32 => bool)) private _authorizationStates;

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);     // 授权已使用事件
    event AuthorizationCanceled(                                                    // 授权已取消事件
        address indexed authorizer,
        bytes32 indexed nonce
    );

    /**
     * @notice 查询授权状态
     * @dev Nonce 是随机生成的 32 字节数据，对每个授权者地址唯一
     *
     * 使用示例：
     * - 在提交授权前，检查 nonce 是否已被使用
     * - 避免提交已使用或已取消的授权，浪费 gas
     *
     * @param authorizer    授权者地址
     * @param nonce         授权的 nonce
     * @return 如果 nonce 已使用或已取消返回 true，否则返回 false
     */
    function authorizationState(address authorizer, bytes32 nonce)
        external
        view
        returns (bool)
    {
        return _authorizationStates[authorizer][nonce];
    }

    /**
     * @notice 执行授权转账（v, r, s 分离版本）
     * @dev 将签名参数组合后调用主函数
     *
     * @param from          付款方地址（授权者）
     * @param to            收款方地址
     * @param value         转账数量
     * @param validAfter    授权生效时间（Unix 时间戳）
     * @param validBefore   授权过期时间（Unix 时间戳）
     * @param nonce         唯一的 nonce（随机生成的 bytes32）
     * @param v             签名的 v 值
     * @param r             签名的 r 值
     * @param s             签名的 s 值
     */
    function _transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _transferWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            abi.encodePacked(r, s, v)
        );
    }

    /**
     * @notice 执行授权转账（主函数）
     * @dev 验证授权、验证签名、标记为已使用、执行转账
     *
     * 工作流程：
     * 1. 验证授权有效性（时间窗口、nonce 未使用）
     * 2. 验证签名（支持 EOA 和智能合约钱包）
     * 3. 标记 nonce 为已使用
     * 4. 执行转账
     *
     * 使用场景：
     * - Alice 签名授权转账 100 USDC 给 Bob
     * - 任何人（包括 Bob 或第三方）都可以提交这笔授权
     * - 提交者支付 gas
     *
     * @param from          付款方地址（授权者）
     * @param to            收款方地址
     * @param value         转账数量
     * @param validAfter    授权生效时间（Unix 时间戳）
     * @param validBefore   授权过期时间（Unix 时间戳）
     * @param nonce         唯一的 nonce（随机生成的 bytes32）
     * @param signature     签名字节数组（EOA 或智能合约钱包生成）
     */
    function _transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes memory signature
    ) internal {
        // 验证授权：检查时间窗口和 nonce 状态
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        // 验证签名
        _requireValidSignature(
            from,
            keccak256(
                abi.encode(
                    TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore,
                    nonce
                )
            ),
            signature
        );

        // 标记授权为已使用
        _markAuthorizationAsUsed(from, nonce);

        // 执行转账
        _transfer(from, to, value);
    }

    /**
     * @notice 接收授权转账（v, r, s 分离版本）
     * @dev 额外检查确保收款方地址与调用者匹配，防止抢跑攻击
     *
     * @param from          付款方地址（授权者）
     * @param to            收款方地址
     * @param value         转账数量
     * @param validAfter    授权生效时间（Unix 时间戳）
     * @param validBefore   授权过期时间（Unix 时间戳）
     * @param nonce         唯一的 nonce
     * @param v             签名的 v 值
     * @param r             签名的 r 值
     * @param s             签名的 s 值
     */
    function _receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _receiveWithAuthorization(
            from,
            to,
            value,
            validAfter,
            validBefore,
            nonce,
            abi.encodePacked(r, s, v)
        );
    }

    /**
     * @notice 接收授权转账（主函数）
     * @dev 与 transferWithAuthorization 的区别：
     *      - 只有收款方（to）可以提交授权
     *      - 防止第三方抢跑（front-running）
     *
     * 防抢跑机制：
     * - 要求调用者必须是收款方（to == msg.sender）
     * - 即使攻击者看到授权签名，也无法替换收款方
     * - 确保只有指定的收款方能接收款项
     *
     * 使用场景：
     * - 商家收款：客户签名授权，只有商家能提交
     * - 工资发放：公司签名授权，只有员工本人能领取
     * - P2P 交易：卖家签名，只有买家能接收
     *
     * 与 transferWithAuthorization 的选择：
     * - receiveWithAuthorization: 需要特定接收方，更安全
     * - transferWithAuthorization: 任何人可提交，更灵活
     *
     * @param from          付款方地址（授权者）
     * @param to            收款方地址（必须是 msg.sender）
     * @param value         转账数量
     * @param validAfter    授权生效时间（Unix 时间戳）
     * @param validBefore   授权过期时间（Unix 时间戳）
     * @param nonce         唯一的 nonce
     * @param signature     签名字节数组（EOA 或智能合约钱包生成）
     */
    function _receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        bytes memory signature
    ) internal {
        // 关键检查：调用者必须是收款方
        // 防止第三方截取授权并提交
        require(to == msg.sender, "FiatTokenV2: caller must be the payee");

        // 验证授权有效性
        _requireValidAuthorization(from, nonce, validAfter, validBefore);

        // 验证签名
        _requireValidSignature(
            from,
            keccak256(
                abi.encode(
                    RECEIVE_WITH_AUTHORIZATION_TYPEHASH,
                    from,
                    to,
                    value,
                    validAfter,
                    validBefore,
                    nonce
                )
            ),
            signature
        );

        // 标记授权为已使用
        _markAuthorizationAsUsed(from, nonce);

        // 执行转账
        _transfer(from, to, value);
    }

    /**
     * @notice 取消授权（v, r, s 分离版本）
     * @dev 授权者可以取消尚未使用的授权
     *
     * @param authorizer    授权者地址
     * @param nonce         要取消的授权的 nonce
     * @param v             签名的 v 值
     * @param r             签名的 r 值
     * @param s             签名的 s 值
     */
    function _cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _cancelAuthorization(authorizer, nonce, abi.encodePacked(r, s, v));
    }

    /**
     * @notice 取消授权（主函数）
     * @dev 允许授权者在授权被使用前取消它
     *
     * 使用场景：
     * - 发现授权信息泄露，立即取消
     * - 改变主意，不想进行转账了
     * - 授权即将过期，主动取消以释放 nonce
     *
     * 工作流程：
     * 1. 检查授权是否未使用
     * 2. 验证取消签名（证明是授权者本人操作）
     * 3. 将 nonce 标记为已使用（取消后不可恢复）
     *
     * @param authorizer    授权者地址
     * @param nonce         要取消的授权的 nonce
     * @param signature     签名字节数组（EOA 或智能合约钱包生成）
     */
    function _cancelAuthorization(
        address authorizer,
        bytes32 nonce,
        bytes memory signature
    ) internal {
        // 要求授权未被使用或取消
        _requireUnusedAuthorization(authorizer, nonce);

        // 验证取消签名
        _requireValidSignature(
            authorizer,
            keccak256(
                abi.encode(CANCEL_AUTHORIZATION_TYPEHASH, authorizer, nonce)
            ),
            signature
        );

        // 标记为已使用（取消后不可再使用）
        _authorizationStates[authorizer][nonce] = true;
        emit AuthorizationCanceled(authorizer, nonce);
    }

    /**
     * @notice 验证签名有效性（内部函数）
     * @dev 使用 EIP-712 类型化数据哈希验证签名
     *
     * @param signer        签名者地址
     * @param dataHash      编码数据结构的哈希
     * @param signature     签名字节数组（EOA 或智能合约钱包生成）
     */
    function _requireValidSignature(
        address signer,
        bytes32 dataHash,
        bytes memory signature
    ) private view {
        require(
            SignatureChecker.isValidSignatureNow(
                signer,
                MessageHashUtils.toTypedDataHash(_domainSeparator(), dataHash),
                signature
            ),
            "FiatTokenV2: invalid signature"
        );
    }

    /**
     * @notice 检查授权是否未使用（内部函数）
     * @param authorizer    授权者地址
     * @param nonce         授权的 nonce
     */
    function _requireUnusedAuthorization(address authorizer, bytes32 nonce)
        private
        view
    {
        require(
            !_authorizationStates[authorizer][nonce],
            "FiatTokenV2: authorization is used or canceled"
        );
    }

    /**
     * @notice 检查授权是否有效（内部函数）
     * @dev 验证时间窗口和 nonce 状态
     *
     * @param authorizer    授权者地址
     * @param nonce         授权的 nonce
     * @param validAfter    授权生效时间（Unix 时间戳）
     * @param validBefore   授权过期时间（Unix 时间戳）
     */
    function _requireValidAuthorization(
        address authorizer,
        bytes32 nonce,
        uint256 validAfter,
        uint256 validBefore
    ) private view {
        // 检查是否已到生效时间
        require(
            now > validAfter,
            "FiatTokenV2: authorization is not yet valid"
        );

        // 检查是否未过期
        require(now < validBefore, "FiatTokenV2: authorization is expired");

        // 检查 nonce 是否未使用
        _requireUnusedAuthorization(authorizer, nonce);
    }

    /**
     * @notice 标记授权为已使用（内部函数）
     * @param authorizer    授权者地址
     * @param nonce         授权的 nonce
     */
    function _markAuthorizationAsUsed(address authorizer, bytes32 nonce)
        private
    {
        _authorizationStates[authorizer][nonce] = true;
        emit AuthorizationUsed(authorizer, nonce);
    }
}
