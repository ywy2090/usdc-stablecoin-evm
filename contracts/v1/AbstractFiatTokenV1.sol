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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AbstractFiatTokenV1 - FiatToken V1 抽象合约
 * @notice 定义 FiatTokenV1 的核心内部接口
 * @dev 此抽象合约继承 IERC20，用于实现 ERC20 标准的内部函数
 *
 * 设计目的：
 * - 为后续版本（V1.1, V2）提供统一的内部函数接口
 * - 允许子合约覆盖内部转账和授权逻辑
 * - 支持合约升级时的向后兼容性
 */
abstract contract AbstractFiatTokenV1 is IERC20 {
    /**
     * @notice 内部授权函数（虚函数）
     * @dev 由子合约实现具体的授权逻辑
     * @param owner 代币所有者地址
     * @param spender 被授权的支出者地址
     * @param value 授权的代币数量
     */
    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal virtual;

    /**
     * @notice 内部转账函数（虚函数）
     * @dev 由子合约实现具体的转账逻辑
     * @param from 发送者地址
     * @param to 接收者地址
     * @param value 转账的代币数量
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual;
}
