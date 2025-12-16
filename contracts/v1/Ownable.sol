/**
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2018 zOS Global Limited.
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

/**
 * @title Ownable - 所有权管理合约
 * @notice Ownable 合约包含一个所有者地址，并提供基本的授权控制功能
 * @dev 源自 OpenZeppelin 的 Ownable 合约
 *
 * 功能说明：
 * - 合约部署时，部署者自动成为所有者
 * - 所有者可以转移所有权给新地址
 * - 提供 onlyOwner 修饰符，限制某些函数只能由所有者调用
 *
 * 修改历史：
 * 1. 将 OwnableStorage 合并到此合约中 (7/13/18)
 * 2. 重新格式化，符合 Solidity 0.6 语法，并添加错误消息 (5/13/20)
 * 3. 将 public 函数改为 external (5/27/20)
 */
contract Ownable {
    // 合约的所有者地址
    address private _owner;

    /**
     * @notice 所有权转移事件
     * @param previousOwner 前任所有者的地址
     * @param newOwner 新所有者的地址
     */
    event OwnershipTransferred(address previousOwner, address newOwner);

    /**
     * @notice 构造函数 - 将合约部署者设置为初始所有者
     */
    constructor() public {
        setOwner(msg.sender);
    }

    /**
     * @notice 查询当前所有者地址
     * @return 所有者的地址
     */
    function owner() external view returns (address) {
        return _owner;
    }

    /**
     * @notice 设置新的所有者地址（内部函数）
     * @param newOwner 新所有者的地址
     */
    function setOwner(address newOwner) internal {
        _owner = newOwner;
    }

    /**
     * @notice 修饰符：仅允许所有者调用
     * @dev 如果调用者不是所有者，则交易回滚
     */
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @notice 转移合约所有权给新地址
     * @dev 只有当前所有者可以调用此函数
     * @param newOwner 新所有者的地址，不能是零地址
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        setOwner(newOwner);
    }
}
