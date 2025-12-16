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

import { MintController } from "./MintController.sol";

/**
 * @title MasterMinter - 主铸币管理器
 * @notice 使用多个控制器来管理实现 MinterManagerInterface 的合约的铸币者
 * @dev MasterMinter 继承 MintController 的所有功能
 *
 * 架构模式：Owner-Controller-Worker 三层模型
 * - Owner: MasterMinter 合约的所有者（最高权限）
 * - Controller: 多个控制器地址（中间管理层）
 * - Worker: 铸币者地址（实际执行铸币的地址）
 *
 * 为什么需要 MasterMinter？
 * - 权限分离：将铸币管理权限分散到多个控制器
 * - 灵活性：每个控制器可以独立管理自己的铸币者
 * - 安全性：降低单点故障风险
 *
 * 实际使用：
 * - Circle 在生产环境中部署独立的 MasterMinter 合约
 * - FiatToken 合约的 masterMinter 地址指向此合约
 * - 通过控制器层次化管理多个铸币者
 *
 * 主要功能（继承自 MintController）：
 * 1. 配置控制器及其对应的铸币者
 * 2. 移除控制器
 * 3. 控制器为其铸币者配置铸币额度
 * 4. 控制器移除其铸币者
 * 5. 增减铸币额度
 *
 * 部署说明：
 * - 部署时需要传入 FiatToken 合约地址作为 _minterManager
 * - 部署后，FiatToken 的 owner 需要调用 updateMasterMinter() 将其设置为 masterMinter
 */
contract MasterMinter is MintController {
    /**
     * @notice 构造函数 - 初始化 MasterMinter
     * @param _minterManager FiatToken 合约地址（实现了 MinterManagerInterface）
     */
    constructor(address _minterManager) public MintController(_minterManager) {}
}
