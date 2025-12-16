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

import { Ownable } from "./Ownable.sol";

/**
 * @title Blacklistable - 黑名单管理合约
 * @notice 允许通过 "blacklister" 角色将账户加入黑名单
 * @dev 抽象合约，提供黑名单管理功能
 *
 * 功能说明：
 * - blacklister 可以将任意地址加入或移出黑名单
 * - 黑名单地址无法进行代币转账（发送和接收）
 * - owner 可以更换 blacklister 地址
 * - 用于合规要求，阻止可疑地址使用代币
 *
 * 设计模式：
 * - 使用抽象方法 _isBlacklisted, _blacklist, _unBlacklist
 * - 允许子合约自定义黑名单存储实现（V2.2 中优化了存储结构）
 */
abstract contract Blacklistable is Ownable {
    address public blacklister;  // 有权管理黑名单的地址
    mapping(address => bool) internal _deprecatedBlacklisted;  // 已废弃的黑名单映射（V2.2 后不再使用）

    event Blacklisted(address indexed _account);       // 地址被加入黑名单事件
    event UnBlacklisted(address indexed _account);     // 地址被移出黑名单事件
    event BlacklisterChanged(address indexed newBlacklister);  // Blacklister 地址变更事件

    /**
     * @notice 修饰符：仅允许 blacklister 调用
     * @dev 如果调用者不是 blacklister，则交易回滚
     */
    modifier onlyBlacklister() {
        require(
            msg.sender == blacklister,
            "Blacklistable: caller is not the blacklister"
        );
        _;
    }

    /**
     * @notice 修饰符：要求账户不在黑名单中
     * @dev 如果账户在黑名单中，则交易回滚
     * @param _account 要检查的地址
     */
    modifier notBlacklisted(address _account) {
        require(
            !_isBlacklisted(_account),
            "Blacklistable: account is blacklisted"
        );
        _;
    }

    /**
     * @notice 查询账户是否在黑名单中
     * @param _account 要查询的地址
     * @return 如果账户在黑名单中返回 true，否则返回 false
     */
    function isBlacklisted(address _account) external view returns (bool) {
        return _isBlacklisted(_account);
    }

    /**
     * @notice 将账户加入黑名单
     * @dev 只有 blacklister 可以调用
     * @param _account 要加入黑名单的地址
     */
    function blacklist(address _account) external onlyBlacklister {
        _blacklist(_account);
        emit Blacklisted(_account);
    }

    /**
     * @notice 将账户从黑名单中移除
     * @dev 只有 blacklister 可以调用
     * @param _account 要移除黑名单的地址
     */
    function unBlacklist(address _account) external onlyBlacklister {
        _unBlacklist(_account);
        emit UnBlacklisted(_account);
    }

    /**
     * @notice 更新 blacklister 地址
     * @dev 只有 owner 可以调用
     * @param _newBlacklister 新 blacklister 的地址，不能是零地址
     */
    function updateBlacklister(address _newBlacklister) external onlyOwner {
        require(
            _newBlacklister != address(0),
            "Blacklistable: new blacklister is the zero address"
        );
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }

    /**
     * @notice 检查账户是否在黑名单中（内部虚函数）
     * @dev 由子合约实现具体的黑名单检查逻辑
     * @param _account 要检查的地址
     * @return 如果账户在黑名单中返回 true，否则返回 false
     */
    function _isBlacklisted(address _account)
        internal
        virtual
        view
        returns (bool);

    /**
     * @notice 将账户加入黑名单的内部辅助方法（内部虚函数）
     * @dev 由子合约实现具体的黑名单添加逻辑
     * @param _account 要加入黑名单的地址
     */
    function _blacklist(address _account) internal virtual;

    /**
     * @notice 将账户从黑名单移除的内部辅助方法（内部虚函数）
     * @dev 由子合约实现具体的黑名单移除逻辑
     * @param _account 要移除黑名单的地址
     */
    function _unBlacklist(address _account) internal virtual;
}
