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

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { AbstractFiatTokenV1 } from "./AbstractFiatTokenV1.sol";
import { Ownable } from "./Ownable.sol";
import { Pausable } from "./Pausable.sol";
import { Blacklistable } from "./Blacklistable.sol";

/**
 * @title FiatTokenV1 - 法币支持的代币合约 V1
 * @notice 由法币储备支持的 ERC20 代币实现
 * @dev 这是 USDC 的第一个主要版本（2018年发布）
 *
 * 核心功能：
 * 1. ERC20 标准：完整实现 transfer、approve、transferFrom 等
 * 2. 铸币/销毁：支持多个铸币者，由 masterMinter 管理
 * 3. 暂停机制：紧急情况下可暂停所有转账
 * 4. 黑名单：阻止可疑地址使用代币
 * 5. 角色管理：owner、pauser、blacklister、masterMinter 分离
 *
 * 存储优化：
 * - balanceAndBlacklistStates: 原计划合并余额和黑名单状态（V1实际未使用）
 * - V2.2 版本实现了这个优化，节省 gas
 *
 * 安全特性：
 * - 使用 SafeMath 防止整数溢出
 * - 初始化保护（只能初始化一次）
 * - 多重角色权限控制
 */
contract FiatTokenV1 is AbstractFiatTokenV1, Ownable, Pausable, Blacklistable {
    using SafeMath for uint256;

    string public name;            // 代币名称，例如 "USD Coin"
    string public symbol;          // 代币符号，例如 "USDC"
    uint8 public decimals;         // 小数位数，通常为 6
    string public currency;        // 对应的法币，例如 "USD"
    address public masterMinter;   // 主铸币者地址，管理所有铸币者
    bool internal initialized;     // 初始化标志，防止重复初始化

    /// @dev 存储地址的余额和黑名单状态的映射
    /// 注意：V1 中此字段只存储余额，黑名单状态存储在 _deprecatedBlacklisted 中
    /// V2.2 版本才真正实现了合并存储（第一位表示黑名单，后255位表示余额）
    mapping(address => uint256) internal balanceAndBlacklistStates;

    mapping(address => mapping(address => uint256)) internal allowed;  // 授权额度映射
    uint256 internal totalSupply_ = 0;                                 // 代币总供应量
    mapping(address => bool) internal minters;                         // 铸币者映射
    mapping(address => uint256) internal minterAllowed;                // 铸币者的铸币额度

    event Mint(address indexed minter, address indexed to, uint256 amount);               // 铸币事件
    event Burn(address indexed burner, uint256 amount);                                   // 销毁事件
    event MinterConfigured(address indexed minter, uint256 minterAllowedAmount);         // 铸币者配置事件
    event MinterRemoved(address indexed oldMinter);                                       // 铸币者移除事件
    event MasterMinterChanged(address indexed newMasterMinter);                          // 主铸币者变更事件

    /**
     * @notice 初始化法币代币合约
     * @dev 此函数代替构造函数，因为使用代理模式部署。只能调用一次
     *
     * 为什么使用 initialize 而不是 constructor？
     * - 代理合约模式下，逻辑合约的 constructor 不会被调用
     * - initialize 在代理部署后通过 delegatecall 调用
     * - 确保每个代理实例只初始化一次
     *
     * @param tokenName       代币名称，例如 "USD Coin"
     * @param tokenSymbol     代币符号，例如 "USDC"
     * @param tokenCurrency   代表的法币，例如 "USD"
     * @param tokenDecimals   小数位数，通常为 6
     * @param newMasterMinter 主铸币者地址（管理所有铸币者）
     * @param newPauser       暂停者地址（可暂停合约）
     * @param newBlacklister  黑名单管理者地址（管理黑名单）
     * @param newOwner        所有者地址（最高权限）
     */
    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenCurrency,
        uint8 tokenDecimals,
        address newMasterMinter,
        address newPauser,
        address newBlacklister,
        address newOwner
    ) public {
        require(!initialized, "FiatToken: contract is already initialized");
        require(
            newMasterMinter != address(0),
            "FiatToken: new masterMinter is the zero address"
        );
        require(
            newPauser != address(0),
            "FiatToken: new pauser is the zero address"
        );
        require(
            newBlacklister != address(0),
            "FiatToken: new blacklister is the zero address"
        );
        require(
            newOwner != address(0),
            "FiatToken: new owner is the zero address"
        );

        name = tokenName;
        symbol = tokenSymbol;
        currency = tokenCurrency;
        decimals = tokenDecimals;
        masterMinter = newMasterMinter;
        pauser = newPauser;
        blacklister = newBlacklister;
        setOwner(newOwner);
        initialized = true;
    }

    /**
     * @notice 修饰符：仅允许铸币者调用
     * @dev 如果调用者不是铸币者，则交易回滚
     */
    modifier onlyMinters() {
        require(minters[msg.sender], "FiatToken: caller is not a minter");
        _;
    }

    /**
     * @notice 铸造新的法币代币到指定地址
     * @dev 铸币者的额度会相应减少，类似 ERC20 的 allowance 机制
     *
     * 铸币流程：
     * 1. 检查铸币者是否有足够的铸币额度
     * 2. 增加总供应量
     * 3. 增加接收者余额
     * 4. 减少铸币者的铸币额度
     *
     * @param _to 接收新铸造代币的地址，不能是零地址或黑名单地址
     * @param _amount 要铸造的代币数量，必须 > 0 且 <= 铸币者的剩余额度
     * @return 操作成功返回 true
     */
    function mint(address _to, uint256 _amount)
        external
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
        notBlacklisted(_to)
        returns (bool)
    {
        require(_to != address(0), "FiatToken: mint to the zero address");
        require(_amount > 0, "FiatToken: mint amount not greater than 0");

        uint256 mintingAllowedAmount = minterAllowed[msg.sender];
        require(
            _amount <= mintingAllowedAmount,
            "FiatToken: mint amount exceeds minterAllowance"
        );

        totalSupply_ = totalSupply_.add(_amount);
        _setBalance(_to, _balanceOf(_to).add(_amount));
        minterAllowed[msg.sender] = mintingAllowedAmount.sub(_amount);
        emit Mint(msg.sender, _to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @notice 修饰符：仅允许主铸币者调用
     * @dev 如果调用者不是 masterMinter，则交易回滚
     */
    modifier onlyMasterMinter() {
        require(
            msg.sender == masterMinter,
            "FiatToken: caller is not the masterMinter"
        );
        _;
    }

    /**
     * @notice 查询铸币者的剩余铸币额度
     * @param minter 要查询的铸币者地址
     * @return 铸币者的剩余铸币额度
     */
    function minterAllowance(address minter) external view returns (uint256) {
        return minterAllowed[minter];
    }

    /**
     * @notice 检查地址是否是铸币者
     * @param account 要检查的地址
     * @return 如果是铸币者返回 true，否则返回 false
     */
    function isMinter(address account) external view returns (bool) {
        return minters[account];
    }

    /**
     * @notice 查询支出者在所有者账户上的剩余授权额度（ERC20 标准）
     * @param owner   代币所有者地址
     * @param spender 支出者地址
     * @return 剩余的授权额度
     */
    function allowance(address owner, address spender)
        external
        override
        view
        returns (uint256)
    {
        return allowed[owner][spender];
    }

    /**
     * @notice 查询代币的总供应量（ERC20 标准）
     * @return 代币总供应量
     */
    function totalSupply() external override view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @notice 查询账户的代币余额（ERC20 标准）
     * @param account  要查询的地址
     * @return balance 账户的代币余额
     */
    function balanceOf(address account)
        external
        override
        view
        returns (uint256)
    {
        return _balanceOf(account);
    }

    /**
     * @notice 授权支出者代表调用者使用指定数量的代币（ERC20 标准）
     * @dev 要求合约未暂停，且调用者和支出者都不在黑名单中
     *
     * 注意：V2.2 移除了对 spender 的黑名单检查，以节省 gas
     *
     * @param spender 被授权的支出者地址
     * @param value   授权的代币数量
     * @return 操作成功返回 true
     */
    function approve(address spender, uint256 value)
        external
        virtual
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice 内部授权函数
     * @param owner     代币所有者地址
     * @param spender   支出者地址
     * @param value     授权数量
     */
    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 使用授权额度从一个地址转账到另一个地址（ERC20 标准）
     * @dev 调用者必须拥有足够的授权额度。要求合约未暂停，且相关方都不在黑名单中
     *
     * 使用场景：
     * - DeFi 协议代表用户转账
     * - 自动支付系统
     *
     * @param from  付款方地址
     * @param to    收款方地址
     * @param value 转账数量
     * @return 操作成功返回 true
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    )
        external
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool)
    {
        require(
            value <= allowed[from][msg.sender],
            "ERC20: transfer amount exceeds allowance"
        );
        _transfer(from, to, value);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
        return true;
    }

    /**
     * @notice 从调用者转账到指定地址（ERC20 标准）
     * @dev 要求合约未暂停，且调用者和接收者都不在黑名单中
     * @param to    收款方地址
     * @param value 转账数量
     * @return 操作成功返回 true
     */
    function transfer(address to, uint256 value)
        external
        override
        whenNotPaused
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice 内部转账处理函数
     * @param from  付款方地址
     * @param to    收款方地址
     * @param value 转账数量
     */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            value <= _balanceOf(from),
            "ERC20: transfer amount exceeds balance"
        );

        _setBalance(from, _balanceOf(from).sub(value));
        _setBalance(to, _balanceOf(to).add(value));
        emit Transfer(from, to, value);
    }

    /**
     * @notice 配置铸币者及其铸币额度
     * @dev 只有 masterMinter 可以调用。如果铸币者已存在，则更新其额度
     *
     * 铸币者管理：
     * - Circle 通常会为不同的业务场景配置多个铸币者
     * - 每个铸币者都有独立的铸币额度限制
     * - 额度用完后需要 masterMinter 重新配置
     *
     * @param minter 铸币者地址
     * @param minterAllowedAmount 允许铸造的代币数量
     * @return 操作成功返回 true
     */
    function configureMinter(address minter, uint256 minterAllowedAmount)
        external
        whenNotPaused
        onlyMasterMinter
        returns (bool)
    {
        minters[minter] = true;
        minterAllowed[minter] = minterAllowedAmount;
        emit MinterConfigured(minter, minterAllowedAmount);
        return true;
    }

    /**
     * @notice 移除铸币者
     * @dev 只有 masterMinter 可以调用。移除后该地址的铸币额度归零
     * @param minter 要移除的铸币者地址
     * @return 操作成功返回 true
     */
    function removeMinter(address minter)
        external
        onlyMasterMinter
        returns (bool)
    {
        minters[minter] = false;
        minterAllowed[minter] = 0;
        emit MinterRemoved(minter);
        return true;
    }

    /**
     * @notice 铸币者销毁自己的代币
     * @dev 调用者必须是铸币者且不在黑名单中，销毁数量不能超过余额
     *
     * 使用场景：
     * - 用户赎回法币时，销毁对应的 USDC
     * - 减少流通中的代币供应量
     *
     * @param _amount 要销毁的代币数量
     */
    function burn(uint256 _amount)
        external
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
    {
        uint256 balance = _balanceOf(msg.sender);
        require(_amount > 0, "FiatToken: burn amount not greater than 0");
        require(balance >= _amount, "FiatToken: burn amount exceeds balance");

        totalSupply_ = totalSupply_.sub(_amount);
        _setBalance(msg.sender, balance.sub(_amount));
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    /**
     * @notice 更新主铸币者地址
     * @dev 只有 owner 可以调用
     * @param _newMasterMinter 新主铸币者地址，不能是零地址
     */
    function updateMasterMinter(address _newMasterMinter) external onlyOwner {
        require(
            _newMasterMinter != address(0),
            "FiatToken: new masterMinter is the zero address"
        );
        masterMinter = _newMasterMinter;
        emit MasterMinterChanged(masterMinter);
    }

    /**
     * @notice 将账户加入黑名单（实现 Blacklistable 抽象方法）
     * @param _account 要加入黑名单的地址
     */
    function _blacklist(address _account) internal override {
        _setBlacklistState(_account, true);
    }

    /**
     * @notice 将账户从黑名单移除（实现 Blacklistable 抽象方法）
     * @param _account 要移除黑名单的地址
     */
    function _unBlacklist(address _account) internal override {
        _setBlacklistState(_account, false);
    }

    /**
     * @notice 设置账户的黑名单状态（内部辅助方法）
     * @dev V1 使用独立的 _deprecatedBlacklisted 映射存储黑名单状态
     *      V2.2 优化为合并到 balanceAndBlacklistStates 中
     *
     * @param _account         账户地址
     * @param _shouldBlacklist 是否应加入黑名单（true=加入，false=移除）
     */
    function _setBlacklistState(address _account, bool _shouldBlacklist)
        internal
        virtual
    {
        _deprecatedBlacklisted[_account] = _shouldBlacklist;
    }

    /**
     * @notice 设置账户余额（内部辅助方法）
     * @dev V1 中 balanceAndBlacklistStates 仅用于存储余额
     *      V2.2 优化为同时存储余额和黑名单状态
     *
     * @param _account 账户地址
     * @param _balance 新的代币余额
     */
    function _setBalance(address _account, uint256 _balance) internal virtual {
        balanceAndBlacklistStates[_account] = _balance;
    }

    /**
     * @notice 检查账户是否在黑名单中（实现 Blacklistable 抽象方法）
     * @param _account 要检查的地址
     * @return 如果账户在黑名单中返回 true，否则返回 false
     */
    function _isBlacklisted(address _account)
        internal
        virtual
        override
        view
        returns (bool)
    {
        return _deprecatedBlacklisted[_account];
    }

    /**
     * @notice 获取账户余额（内部辅助方法）
     * @param _account  账户地址
     * @return          账户的代币余额
     */
    function _balanceOf(address _account)
        internal
        virtual
        view
        returns (uint256)
    {
        return balanceAndBlacklistStates[_account];
    }
}
