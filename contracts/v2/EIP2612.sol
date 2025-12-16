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
import { MessageHashUtils } from "../util/MessageHashUtils.sol";
import { SignatureChecker } from "../util/SignatureChecker.sol";

/**
 * @title EIP-2612 - Gas 抽象授权（Permit）
 * @notice 提供免 gas 的代币授权功能
 * @dev 实现 EIP-2612 标准，允许用户通过链下签名完成授权
 *
 * 传统授权的问题：
 * - 用户必须先调用 approve()，消耗 gas
 * - DApp 无法代用户支付 gas
 * - 用户体验差，需要两笔交易（approve + transferFrom）
 *
 * EIP-2612 解决方案：
 * - 用户在链下签署授权消息（免 gas）
 * - 第三方（或接收方）提交签名到链上
 * - 合约验证签名并完成授权
 * - 只需一笔交易完成授权+转账
 *
 * 使用场景：
 * - DEX 交易：用户签名授权，DEX 代付 gas
 * - 跨链桥：简化用户操作流程
 * - DApp 补贴：应用方为用户支付 gas
 *
 * 安全机制：
 * - 每个地址有独立的 nonce 计数器，防止重放攻击
 * - 设置截止时间（deadline），过期签名无效
 * - 使用 EIP-712 结构化签名，钱包可展示清晰的签名内容
 *
 * V2.2 新增：
 * - 支持 EIP-1271 智能合约钱包签名验证
 * - 允许使用 uint256.max 作为 deadline 表示永不过期
 */
abstract contract EIP2612 is AbstractFiatTokenV2, EIP712Domain {
    // Permit 消息的类型哈希
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32
        public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // 每个地址的 permit nonce 计数器
    // 用于防止签名重放攻击
    mapping(address => uint256) private _permitNonces;

    /**
     * @notice 查询地址的 permit nonce
     * @dev 每次使用 permit 后，nonce 自动递增
     * @param owner 代币所有者地址（授权者）
     * @return 下一个 nonce 值
     */
    function nonces(address owner) external view returns (uint256) {
        return _permitNonces[owner];
    }

    /**
     * @notice 验证并执行签名授权（v, r, s 分离版本）
     * @dev 将签名参数组合后调用主 _permit 函数
     *
     * 使用示例：
     * 1. 用户在前端签署授权消息
     * 2. DApp 获取签名的 v, r, s 值
     * 3. DApp 调用 permit(owner, spender, value, deadline, v, r, s)
     * 4. 合约验证签名并完成授权
     *
     * @param owner     代币所有者地址（授权者）
     * @param spender   支出者地址（被授权者）
     * @param value     授权数量
     * @param deadline  签名过期时间（Unix 时间戳），或 uint256.max 表示永不过期
     * @param v         签名的 v 值
     * @param r         签名的 r 值
     * @param s         签名的 s 值
     */
    function _permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        _permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }

    /**
     * @notice 验证并执行签名授权（主函数）
     * @dev 验证签名、检查过期时间、执行授权
     *
     * 工作流程：
     * 1. 检查签名是否过期
     * 2. 构造 EIP-712 类型化数据哈希
     * 3. 验证签名（支持 EOA 和智能合约钱包）
     * 4. 递增 nonce（防止重放）
     * 5. 执行授权
     *
     * 签名格式：
     * - EOA 钱包：r, s, v 按顺序打包（65字节）
     * - 智能合约钱包：遵循 EIP-1271 标准
     *
     * @param owner      代币所有者地址（授权者）
     * @param spender    支出者地址（被授权者）
     * @param value      授权数量
     * @param deadline   签名过期时间（Unix 时间戳），或 uint256.max 表示永不过期
     * @param signature  签名字节数组（EOA 或智能合约钱包生成）
     */
    function _permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) internal {
        // 检查签名是否过期
        // uint256.max 表示永不过期（V2.2 新增）
        require(
            deadline == type(uint256).max || deadline >= now,
            "FiatTokenV2: permit is expired"
        );

        // 构造 EIP-712 类型化数据哈希
        // 包含：类型哈希、owner、spender、value、nonce、deadline
        bytes32 typedDataHash = MessageHashUtils.toTypedDataHash(
            _domainSeparator(),
            keccak256(
                abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    _permitNonces[owner]++,  // 使用后自动递增，防止重放攻击
                    deadline
                )
            )
        );

        // 验证签名有效性
        // 支持 EOA 钱包（ECDSA）和智能合约钱包（EIP-1271）
        require(
            SignatureChecker.isValidSignatureNow(
                owner,
                typedDataHash,
                signature
            ),
            "EIP2612: invalid signature"
        );

        // 执行授权
        _approve(owner, spender, value);
    }
}
