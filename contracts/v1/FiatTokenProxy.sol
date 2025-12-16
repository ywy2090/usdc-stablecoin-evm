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

import {
    AdminUpgradeabilityProxy
} from "../upgradeability/AdminUpgradeabilityProxy.sol";

/**
 * @title FiatTokenProxy - FiatToken 代理合约
 * @notice 此合约代理 FiatToken 的所有调用，并支持合约升级
 * @dev 继承 AdminUpgradeabilityProxy，使用 delegatecall 转发调用到实现合约
 *
 * 代理模式的优势：
 * 1. 合约地址不变：用户和交易所只需要记录代理合约地址
 * 2. 可升级性：可以部署新的实现合约并升级，无需迁移数据
 * 3. 存储持久化：所有状态数据存储在代理合约中
 *
 * 工作原理：
 * - 用户调用代理合约的函数
 * - 代理合约通过 delegatecall 调用实现合约
 * - 实现合约的代码在代理合约的上下文中执行
 * - 状态变更保存在代理合约的存储中
 *
 * 升级流程：
 * 1. 部署新的实现合约（例如 FiatTokenV2）
 * 2. proxyOwner 调用 upgradeTo() 更新实现合约地址
 * 3. 后续调用自动转发到新实现合约
 *
 * 注意事项：
 * - 新实现合约必须与旧版本的存储布局兼容
 * - 不能随意调整或删除已有的状态变量顺序
 * - 只能在末尾添加新的状态变量
 */
contract FiatTokenProxy is AdminUpgradeabilityProxy {
    /**
     * @notice 构造函数 - 初始化代理合约
     * @param implementationContract 实现合约的地址（例如 FiatTokenV1）
     */
    constructor(address implementationContract)
        public
        AdminUpgradeabilityProxy(implementationContract)
    {}
}
