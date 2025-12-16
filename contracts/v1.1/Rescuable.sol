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

import { Ownable } from "../v1/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @title Rescuable - 代币救援合约
 * @notice 允许从合约中救援（取出）误转入的 ERC20 代币
 * @dev V1.1 版本新增的功能模块
 *
 * 使用场景：
 * - 用户误将其他 ERC20 代币转入 USDC 合约地址
 * - 用户误将 USDC 转入 USDC 合约自身地址
 * - 这些代币会被"锁定"在合约中，无法正常取出
 *
 * 解决方案：
 * - 引入 rescuer 角色，可以将锁定的代币转出
 * - 使用 SafeERC20 库确保转账安全
 * - owner 可以更换 rescuer 地址
 *
 * 实际案例：
 * - 2021年2月，Circle 将锁定在合约中的 USDC 转移到"lost and found"地址
 * - 然后将该地址加入黑名单，防止再次误转
 *
 * 安全考虑：
 * - rescuer 是高权限角色，需要妥善保管
 * - 不应该用于救援合约正常运营的资金
 */
contract Rescuable is Ownable {
    using SafeERC20 for IERC20;

    address private _rescuer;  // 有权救援代币的地址

    event RescuerChanged(address indexed newRescuer);  // Rescuer 地址变更事件

    /**
     * @notice 查询当前 rescuer 地址
     * @return Rescuer 的地址
     */
    function rescuer() external view returns (address) {
        return _rescuer;
    }

    /**
     * @notice 修饰符：仅允许 rescuer 调用
     * @dev 如果调用者不是 rescuer，则交易回滚
     */
    modifier onlyRescuer() {
        require(msg.sender == _rescuer, "Rescuable: caller is not the rescuer");
        _;
    }

    /**
     * @notice 救援锁定在合约中的 ERC20 代币
     * @dev 只有 rescuer 可以调用。使用 SafeERC20 确保转账安全
     *
     * 使用示例：
     * 1. 用户误转 100 DAI 到 USDC 合约
     * 2. rescuer 调用 rescueERC20(DAI地址, 用户地址, 100)
     * 3. DAI 被转回给用户
     *
     * @param tokenContract 要救援的 ERC20 代币合约地址
     * @param to        接收代币的地址（通常是误转者）
     * @param amount    要转出的代币数量
     */
    function rescueERC20(
        IERC20 tokenContract,
        address to,
        uint256 amount
    ) external onlyRescuer {
        tokenContract.safeTransfer(to, amount);
    }

    /**
     * @notice 更新 rescuer 地址
     * @dev 只有 owner 可以调用
     * @param newRescuer 新 rescuer 的地址，不能是零地址
     */
    function updateRescuer(address newRescuer) external onlyOwner {
        require(
            newRescuer != address(0),
            "Rescuable: new rescuer is the zero address"
        );
        _rescuer = newRescuer;
        emit RescuerChanged(newRescuer);
    }
}
