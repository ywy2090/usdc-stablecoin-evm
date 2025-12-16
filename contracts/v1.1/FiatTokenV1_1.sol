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

import { FiatTokenV1 } from "../v1/FiatTokenV1.sol";
import { Rescuable } from "./Rescuable.sol";

/**
 * @title FiatTokenV1_1 - 法币代币 V1.1 版本
 * @notice 在 V1 基础上增加 Rescuable 功能的 USDC 合约
 * @dev 继承 FiatTokenV1 和 Rescuable，通过多重继承添加救援功能
 *
 * 版本更新（2020年5月）：
 * - 新增：Rescuable 功能（救援误转入的代币）
 * - 新增：rescuer 角色和相关管理功能
 * - 升级：Solidity 版本从 0.4.24 升级到 0.6.8
 *
 * 合约功能（继承自 V1）：
 * - ERC20 标准代币功能
 * - 铸币/销毁机制
 * - 暂停功能
 * - 黑名单功能
 * - 角色权限管理
 *
 * 新增功能（V1.1）：
 * - 救援误转入的 ERC20 代币
 *
 * 升级路径：
 * V1 (2018) -> V1.1 (2020) -> V2 (2020) -> V2.1 (2021) -> V2.2 (2023)
 *
 * 注意事项：
 * - 此合约为空实现，所有功能来自父合约
 * - 通过代理模式部署和升级
 * - 存储布局必须与 V1 兼容
 */
contract FiatTokenV1_1 is FiatTokenV1, Rescuable {
    // 无需额外代码，所有功能通过继承获得
    // FiatTokenV1 提供核心代币功能
    // Rescuable 提供代币救援功能
}
