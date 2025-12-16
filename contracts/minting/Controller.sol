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

/**
 * @title Controller - 控制器管理合约
 * @notice Owner-Controller-Worker 模型的通用实现
 * @dev 一个 owner 管理多个 controllers，每个 controller 管理一个 worker
 *
 * 架构说明：
 * - Owner（所有者）：合约部署者或所有权转移后的地址
 * - Controller（控制器）：中间管理层，可以有多个
 * - Worker（工作者）：实际执行操作的地址，可以在不同控制器间复用
 *
 * 为什么需要这个模型？
 * 1. 权限分层：避免所有操作都需要 owner 执行
 * 2. 灵活管理：可以快速添加/移除控制器
 * 3. 责任分离：不同控制器负责不同的 worker
 * 4. 可复用性：同一个 worker 可以被多个控制器管理
 *
 * 实际应用场景：
 * - Circle 的多区域管理：每个地区有自己的控制器
 * - 多部门管理：财务、运营等不同部门有各自的控制器
 * - 灾备管理：主控制器和备用控制器
 */
contract Controller is Ownable {
    /**
     * @dev 控制器映射
     * 一个控制器地址对应一个工作者地址
     * controllers[controller] = worker
     */
    mapping(address => address) internal controllers;

    event ControllerConfigured(        // 控制器配置事件
        address indexed _controller,
        address indexed _worker
    );
    event ControllerRemoved(address indexed _controller);  // 控制器移除事件

    /**
     * @notice 修饰符：确保调用者是有效的控制器
     * @dev 要求 controllers[msg.sender] 不为零地址
     */
    modifier onlyController() {
        require(
            controllers[msg.sender] != address(0),
            "The value of controllers[msg.sender] must be non-zero"
        );
        _;
    }

    /**
     * @notice 查询控制器对应的工作者地址
     * @param _controller 控制器地址
     * @return 对应的工作者地址，如果未配置则返回零地址
     */
    function getWorker(address _controller) external view returns (address) {
        return controllers[_controller];
    }

    // ========== Owner 专用函数 ==========

    /**
     * @notice 配置控制器及其对应的工作者
     * @dev 只有 owner 可以调用
     *
     * 使用说明：
     * - 如果控制器已存在，将更新其工作者地址
     * - 要禁用控制器，使用 removeController() 而不是设置零地址
     *
     * @param _controller 要配置的控制器地址（不能是零地址）
     * @param _worker 要设置的工作者地址（不能是零地址）
     */
    function configureController(address _controller, address _worker)
        public
        onlyOwner
    {
        require(
            _controller != address(0),
            "Controller must be a non-zero address"
        );
        require(_worker != address(0), "Worker must be a non-zero address");
        controllers[_controller] = _worker;
        emit ControllerConfigured(_controller, _worker);
    }

    /**
     * @notice disables a controller by setting its worker to address(0).
     * @param _controller The controller to disable.
     */
    function removeController(address _controller) public onlyOwner {
        require(
            _controller != address(0),
            "Controller must be a non-zero address"
        );
        require(
            controllers[_controller] != address(0),
            "Worker must be a non-zero address"
        );
        controllers[_controller] = address(0);
        emit ControllerRemoved(_controller);
    }
}
