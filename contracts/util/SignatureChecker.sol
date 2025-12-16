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

import { ECRecover } from "./ECRecover.sol";
import { IERC1271 } from "../interface/IERC1271.sol";

/**
 * @title SignatureChecker - 签名验证助手库
 * @notice 统一验证 EOA 和智能合约钱包的签名
 * @dev 无缝支持 ECDSA 签名（EOA）和 ERC-1271 签名（智能合约钱包）
 *
 * 为什么需要这个库？
 * - EOA（外部账户）：使用 ECDSA 签名（私钥签名）
 * - 智能合约钱包：使用 ERC-1271 标准验证签名
 * - 需要统一的验证接口支持两种钱包
 *
 * 智能合约钱包示例：
 * - Gnosis Safe（多签钱包）
 * - Argent 钱包
 * - 各种多签、社交恢复钱包
 *
 * V2.2 版本新增：
 * - 在 permit() 和各种授权函数中使用此库
 * - 让智能合约钱包也能使用 gas 抽象功能
 *
 * 源自：
 * OpenZeppelin 的 SignatureChecker 库
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/21bb89ef5bfc789b9333eb05e3ba2b7b284ac77c/contracts/utils/cryptography/SignatureChecker.sol
 */
library SignatureChecker {
    /**
     * @notice 验证签名是否有效（统一接口）
     * @dev 自动检测签名者类型：
     *      - 如果是 EOA：使用 ECDSA 恢复地址验证
     *      - 如果是合约：使用 ERC-1271 标准验证
     *
     * 使用场景：
     * - permit() 函数验证授权签名
     * - transferWithAuthorization() 验证转账授权
     * - 所有需要链下签名的场景
     *
     * @param signer        声明的签名者地址
     * @param digest        签名消息的 Keccak-256 哈希
     * @param signature     签名字节数组
     * @return 签名有效返回 true，否则返回 false
     */
    function isValidSignatureNow(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) external view returns (bool) {
        // 检查签名者是否是合约
        if (!isContract(signer)) {
            // EOA 账户：使用 ECDSA 恢复地址并比较
            return ECRecover.recover(digest, signature) == signer;
        }
        // 智能合约钱包：使用 ERC-1271 标准验证
        return isValidERC1271SignatureNow(signer, digest, signature);
    }

    /**
     * @notice 验证 ERC-1271 智能合约钱包签名
     * @dev 调用合约的 isValidSignature() 函数进行验证
     *
     * ERC-1271 标准：
     * - 合约实现 isValidSignature(bytes32, bytes) 函数
     * - 验证成功返回魔数 0x1626ba7e
     * - 验证失败返回其他值或回滚
     *
     * 重要提示：
     * - 与 ECDSA 签名不同，合约签名是可撤销的
     * - 同一个签名在不同区块可能有不同结果
     * - 例如：多签钱包更换签名者后，旧签名失效
     *
     * @param signer        智能合约钱包地址
     * @param digest        签名消息的 Keccak-256 哈希
     * @param signature     签名字节数组
     * @return 签名有效返回 true，否则返回 false
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool) {
        // 使用 staticcall 调用合约的 isValidSignature 函数
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(
                IERC1271.isValidSignature.selector,
                digest,
                signature
            )
        );
        // 验证：调用成功 && 返回值至少32字节 && 返回的是正确的魔数
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) ==
            bytes32(IERC1271.isValidSignature.selector));
    }

    /**
     * @notice 检查地址是否是智能合约
     * @dev 使用 extcodesize 汇编指令检查代码大小
     *
     * 注意事项：
     * - 在合约构造函数中，extcodesize 返回 0
     * - 已自毁的合约 extcodesize 也返回 0
     *
     * @param addr 要检查的地址
     * @return 是合约返回 true，是 EOA 返回 false
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
