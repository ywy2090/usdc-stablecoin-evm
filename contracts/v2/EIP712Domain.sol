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

// solhint-disable func-name-mixedcase

/**
 * @title EIP712Domain - EIP-712 域分隔符合约
 * @notice 提供 EIP-712 域分隔符功能，用于结构化数据签名
 * @dev EIP-712 是以太坊结构化数据签名标准
 *
 * EIP-712 作用：
 * - 让用户清楚看到要签名的内容（而不是一串 hash）
 * - 防止签名被用在不同的合约或链上（通过域分隔符绑定）
 * - 支持钱包友好的签名展示
 *
 * 域分隔符 (Domain Separator) 包含：
 * - 合约名称
 * - 合约版本
 * - 链 ID（防止跨链重放攻击）
 * - 合约地址（防止跨合约重放攻击）
 *
 * 版本演进：
 * - V2.0/V2.1: 域分隔符在初始化时计算并缓存（静态）
 * - V2.2: 改为动态计算，支持硬分叉后的链 ID 变化
 *
 * 使用场景：
 * - permit() 免 gas 授权
 * - transferWithAuthorization() 免 gas 转账
 * - 所有需要链下签名的操作
 */
contract EIP712Domain {
    // 已废弃的缓存域分隔符
    // 原本在 V2.0/V2.1 中用于缓存域分隔符
    // V2.2+ 改为动态计算，此字段保留以保持存储布局兼容性
    bytes32 internal _DEPRECATED_CACHED_DOMAIN_SEPARATOR;

    /**
     * @notice 获取 EIP712 域分隔符（公开函数）
     * @dev 按 EIP-712 标准，函数名必须全大写
     * @return EIP712 域分隔符（bytes32）
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /**
     * @notice 获取 EIP712 域分隔符（内部虚函数）
     * @dev 子合约可以覆盖此函数以改变域分隔符的计算方式
     *      - V2.0/V2.1: 返回缓存的域分隔符
     *      - V2.2+: 动态计算域分隔符（考虑链 ID 变化）
     *
     * @return EIP712 域分隔符（bytes32）
     */
    function _domainSeparator() internal virtual view returns (bytes32) {
        return _DEPRECATED_CACHED_DOMAIN_SEPARATOR;
    }
}
