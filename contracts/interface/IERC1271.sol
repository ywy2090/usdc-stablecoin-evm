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

/**
 * @title IERC1271 - ERC-1271 标准接口
 * @notice 智能合约钱包的签名验证标准
 * @dev ERC-1271 标准定义：https://eips.ethereum.org/EIPS/eip-1271
 *
 * ERC-1271 是什么？
 * - 智能合约无法像 EOA 一样使用私钥签名
 * - ERC-1271 定义了合约验证签名的标准接口
 * - 让智能合约钱包也能参与需要签名的操作
 *
 * 为什么需要 ERC-1271？
 * - 多签钱包：需要多个签名者批准
 * - 社交恢复：通过社交关系恢复钱包
 * - 自定义逻辑：根据业务逻辑验证签名
 *
 * 实际应用：
 * - Gnosis Safe：多签钱包验证
 * - Argent：社交恢复钱包
 * - USDC V2.2：permit() 和各种授权函数支持智能合约钱包
 *
 * 工作原理：
 * 1. 合约钱包实现 isValidSignature() 函数
 * 2. 外部调用此函数验证签名
 * 3. 合约内部执行自定义验证逻辑（如检查多签）
 * 4. 验证通过返回魔数 0x1626ba7e，失败返回其他值或回滚
 */
interface IERC1271 {
    /**
     * @notice 验证签名是否对提供的数据有效
     * @dev 合约需要实现此函数来验证签名
     *
     * 实现示例（多签钱包）：
     * 1. 解析签名数据，提取多个签名者的签名
     * 2. 验证每个签名者的签名
     * 3. 检查是否达到最低签名数量要求
     * 4. 通过返回 0x1626ba7e，失败回滚或返回其他值
     *
     * 魔数 0x1626ba7e 的由来：
     * - 是 isValidSignature(bytes32,bytes) 函数选择器的前 4 字节
     * - 用作验证成功的标识
     *
     * @param hash          要签名的数据的哈希
     * @param signature     与数据哈希关联的签名字节数组
     * @return magicValue   验证通过返回魔数 0x1626ba7e，否则返回其他值
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);
}
