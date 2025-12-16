/**
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2016 Smart Contract Solutions, Inc.
 * Copyright (c) 2018-2020 CENTRE SECZ
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

pragma solidity 0.6.12;

import { Ownable } from "./Ownable.sol";

/**
 * @title Pausable - 暂停机制合约
 * @notice 允许子合约实现紧急停止机制的基础合约
 * @dev 源自 OpenZeppelin 的 Pausable 合约
 *
 * 功能说明：
 * - 引入 pauser 角色，可以暂停和恢复合约
 * - 提供 whenNotPaused 修饰符，使函数只能在未暂停时调用
 * - owner 可以更换 pauser 地址
 * - 用于紧急情况下冻结所有代币转账操作
 *
 * 修改历史：
 * 1. 添加 pauser 角色，将 pause/unpause 改为 onlyPauser (6/14/2018)
 * 2. 从 pause/unpause 中移除 whenNotPause/whenPaused (6/14/2018)
 * 3. 移除 whenPaused (6/14/2018)
 * 4. 切换到使用 ZeppelinOS 的 ownable 库 (7/12/18)
 * 5. 移除构造函数 (7/13/18)
 * 6. 重新格式化，符合 Solidity 0.6 语法并添加错误消息 (5/13/20)
 * 7. 将 public 函数改为 external (5/27/20)
 */
contract Pausable is Ownable {
    event Pause();      // 暂停事件
    event Unpause();    // 恢复事件
    event PauserChanged(address indexed newAddress);  // Pauser 地址变更事件

    address public pauser;      // 有权暂停合约的地址
    bool public paused = false; // 合约是否处于暂停状态

    /**
     * @notice 修饰符：仅在合约未暂停时可调用
     * @dev 使函数只能在合约未暂停状态下执行
     */
    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    /**
     * @notice 修饰符：仅允许 pauser 调用
     * @dev 如果调用者不是 pauser，则交易回滚
     */
    modifier onlyPauser() {
        require(msg.sender == pauser, "Pausable: caller is not the pauser");
        _;
    }

    /**
     * @notice 暂停合约
     * @dev 只有 pauser 可以调用，触发停止状态，所有转账操作将被禁止
     */
    function pause() external onlyPauser {
        paused = true;
        emit Pause();
    }

    /**
     * @notice 恢复合约
     * @dev 只有 pauser 可以调用，返回正常状态，恢复所有转账操作
     */
    function unpause() external onlyPauser {
        paused = false;
        emit Unpause();
    }

    /**
     * @notice 更新 pauser 地址
     * @dev 只有 owner 可以调用
     * @param _newPauser 新 pauser 的地址，不能是零地址
     */
    function updatePauser(address _newPauser) external onlyOwner {
        require(
            _newPauser != address(0),
            "Pausable: new pauser is the zero address"
        );
        pauser = _newPauser;
        emit PauserChanged(pauser);
    }
}
