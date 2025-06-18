// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Interface of the ERC20 standard.
 */
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

/**
 * @dev Implementation of the {IERC20} interface.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return 18; }
    function totalSupply() public view virtual override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint256) { return _balances[account]; }
    
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// ===== Your Contract Starts Here =====

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function WETH() external pure returns (address);
}

contract ReflectingToken is ERC20, Ownable {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public uniswapV2Pair;
    address public immutable WETH;

    enum DistributionType { PUSH, PULL }
    DistributionType public distributionMethod;
    
    uint256 public taxFeePercent = 5;
    uint256 public swapThreshold;

    // --- PULL Method Variables ---
    mapping(address => Share) public shares;
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 private constant MAGNITUDE = 2**128;
    uint256 private magnifiedDividendPerShare;

    // --- PUSH Method Variables ---
    address[] private _holders;
    mapping(address => uint256) private _holderIndex;
    uint256 public lastPushDistributionIndex;
    uint256 public pushDistributionBatchSize = 100;
    
    // --- General Variables ---
    mapping(address => bool) public isExcludedFromDividends;
    uint256 public minBalanceForDividends;
    bool private _isInitialized;
    bool private swapping;

    struct Share {
        uint256 amount;
        int256 magnifiedDividendCorrections;
    }

    modifier lockTheSwap {
        swapping = true;
        _;
        swapping = false;
    }

    event TaxFeeUpdated(uint256 newFee);
    event SwapThresholdUpdated(uint256 newThreshold);
    event DividendsDistributed(uint256 amount);
    event DividendClaimed(address indexed holder, uint256 amount);
    event ExcludedFromDividends(address indexed account, bool isExcluded);
    event LiquidityPairSet(address indexed pair);
    event DistributionMethodChanged(DistributionType newMethod);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _supply,
        address _routerAddress,
        address _wethAddress
    )
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        uniswapV2Router = IUniswapV2Router02(_routerAddress);
        WETH = _wethAddress;
        
        uint256 initialSupply = _supply * (10**decimals());

        swapThreshold = initialSupply / 1000;
        minBalanceForDividends = initialSupply / 10000; 

        distributionMethod = DistributionType.PULL;

        address deployer = msg.sender;
        _excludeFromDividends(address(this), true);
        _excludeFromDividends(address(uniswapV2Router), true);
        _excludeFromDividends(deployer, true);

        _mint(deployer, initialSupply);
        _isInitialized = true;
    }

    receive() external payable {}

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (from != address(0) && to != address(0) && !swapping && from != uniswapV2Pair && from != owner() && uniswapV2Pair != address(0)) {
            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance >= swapThreshold) {
                _swapAndDistributeDividends(contractTokenBalance);
            }
        }
        super._beforeTokenTransfer(from, to, amount);
    }
    
    function _transfer(address from, address to, uint256 amount) internal virtual override {
        uint256 taxAmount = 0;
        if (taxFeePercent > 0 && from != owner() && to != owner() && from != uniswapV2Pair && to != uniswapV2Pair) {
            taxAmount = (amount * taxFeePercent) / 100;
        }
        
        uint256 transferAmount = amount - taxAmount;
        super._transfer(from, to, transferAmount);

        if (taxAmount > 0) {
            super._transfer(from, address(this), taxAmount);
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (!_isInitialized) { return; }
        
        // --- Manage PULL method shares ---
        if(from != address(0)) { try this.setPullBalance(from, balanceOf(from)) {} catch {} }
        if(to != address(0)) { try this.setPullBalance(to, balanceOf(to)) {} catch {} }

        // --- Manage PUSH method holder list ---
        if (balanceOf(from) == 0 && _holderIndex[from] > 0) { _removeHolder(from); }
        if (balanceOf(to) > 0 && _holderIndex[to] == 0) { _addHolder(to); }

        super._afterTokenTransfer(from, to, amount);
    }
    
    function _swapAndDistributeDividends(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);
        
        uint256 dividends = address(this).balance;
        if (dividends > 0) {
            _distributeDividends(dividends);
            emit DividendsDistributed(dividends);
        }
    }

    function _distributeDividends(uint256 amount) private {
        if (distributionMethod == DistributionType.PULL) {
            if (totalShares > 0) {
                 totalDividends += amount;
                 magnifiedDividendPerShare += ((amount * MAGNITUDE) / totalShares);
            }
        } else { // PUSH Method
            if (totalSupply() == 0 || _holders.length == 0) return;

            uint256 rewardsPerToken = amount * 1e18 / totalSupply();
            if (rewardsPerToken == 0) return;

            uint256 gasUsed = 0;
            uint256 gasLimit = gasleft() - 20000;
            uint256 shareholderCount = _holders.length;
            uint256 processedCount = 0;
            
            while (gasUsed < gasLimit && processedCount < pushDistributionBatchSize) {
                if (lastPushDistributionIndex >= shareholderCount) {
                    lastPushDistributionIndex = 0;
                }
                address holder = _holders[lastPushDistributionIndex];
                uint256 balance = balanceOf(holder);
                
                if(balance > 0) {
                    uint256 reward = balance * rewardsPerToken / 1e18;
                    if(reward > 0) {
                        (bool success, ) = holder.call{value: reward}("");
                        // FIX: Check if the send was successful
                        if(!success) { gasUsed = gasLimit; } // Stop processing if a send fails
                    }
                }
                
                processedCount++;
                lastPushDistributionIndex++;
                gasUsed = gasleft() < gasLimit ? gasLimit - gasleft() : 0;
            }
        }
    }

    // --- Dividend Management Functions ---

    function claim() external {
        require(distributionMethod == DistributionType.PULL, "Claim function is only available in PULL mode.");
        _claim(msg.sender);
    }
    
    function _claim(address account) private {
        uint256 owed = getUnpaidDividends(account);
        if(owed > 0) {
            shares[account].magnifiedDividendCorrections += int256((owed * MAGNITUDE) / shares[account].amount);
            (bool success, ) = account.call{value: owed}("");
            // FIX: Check if the send was successful
            require(success, "Transfer failed.");
            emit DividendClaimed(account, owed);
        }
    }

    function getUnpaidDividends(address account) public view returns (uint256) {
        if (shares[account].amount == 0) return 0;
        uint256 shareholderTotalDividends = (magnifiedDividendPerShare * shares[account].amount) / MAGNITUDE;
        int256 shareholderCorrectedDividends = int256(shareholderTotalDividends) + shares[account].magnifiedDividendCorrections;
        return uint256(shareholderCorrectedDividends);
    }

    function setPullBalance(address shareholder, uint256 newBalance) external {
        require(msg.sender == address(this), "Only callable by the token contract");
        if(isExcludedFromDividends[shareholder]) return;
        uint256 oldBalance = shares[shareholder].amount;
        if (newBalance < minBalanceForDividends) newBalance = 0;
        if (newBalance == oldBalance) return;
        if (newBalance > oldBalance) {
            uint256 amountAdded = newBalance - oldBalance;
            totalShares += amountAdded;
            shares[shareholder].magnifiedDividendCorrections -= int256((magnifiedDividendPerShare * amountAdded) / MAGNITUDE);
        } else {
            uint256 amountRemoved = oldBalance - newBalance;
            totalShares -= amountRemoved;
            shares[shareholder].magnifiedDividendCorrections += int256((magnifiedDividendPerShare * amountRemoved) / MAGNITUDE);
        }
        shares[shareholder].amount = newBalance;
    }
    
    function _addHolder(address holder) private {
        if (isExcludedFromDividends[holder]) return;
        _holderIndex[holder] = _holders.length;
        _holders.push(holder);
    }

    function _removeHolder(address holder) private {
        uint256 index = _holderIndex[holder];
        if (index >= _holders.length) return; // Prevent out of bounds access
        address lastHolder = _holders[_holders.length - 1];
        _holders[index] = lastHolder;
        _holderIndex[lastHolder] = index;
        _holders.pop();
        delete _holderIndex[holder];
    }

    // --- Owner-Only Configuration Functions ---
    
    function setDistributionMethod(DistributionType _newMethod) external onlyOwner {
        distributionMethod = _newMethod;
        emit DistributionMethodChanged(_newMethod);
    }

    function setPushBatchSize(uint256 _newSize) external onlyOwner {
        require(_newSize > 0 && _newSize <= 500, "Batch size must be between 1 and 500");
        pushDistributionBatchSize = _newSize;
    }

    function setLiquidityPair(address _pairAddress) external onlyOwner {
        require(uniswapV2Pair == address(0), "Pair already set.");
        uniswapV2Pair = _pairAddress;
        _excludeFromDividends(_pairAddress, true);
        emit LiquidityPairSet(_pairAddress);
    }
    
    function setTaxFeePercent(uint256 _newFee) external onlyOwner {
        require(_newFee <= 20, "Tax fee cannot exceed 20%");
        taxFeePercent = _newFee;
        emit TaxFeeUpdated(_newFee);
    }

    function setSwapThreshold(uint256 _newThreshold) external onlyOwner {
        swapThreshold = _newThreshold;
        emit SwapThresholdUpdated(_newThreshold);
    }
    
    function setMinBalanceForDividends(uint256 _minBalance) external onlyOwner {
        minBalanceForDividends = _minBalance;
    }
    
    function excludeFromDividends(address account, bool isExcluded) external onlyOwner {
        _excludeFromDividends(account, isExcluded);
    }
    
    function _excludeFromDividends(address account, bool isExcluded) private {
        require(account != address(0), "Cannot exclude the zero address");
        require(isExcludedFromDividends[account] != isExcluded, "Account is already set to this status");
        isExcludedFromDividends[account] = isExcluded;

        if (isExcluded && _holderIndex[account] > 0) {
            _removeHolder(account);
        } else if (!isExcluded && balanceOf(account) > 0) {
            // Check if holder is already in the list to prevent duplicates
            if (_holderIndex[account] == 0 && _holders.length > 0 && _holders[0] != account) {
                 _addHolder(account);
            } else if (_holders.length == 0) {
                 _addHolder(account);
            }
        }

        emit ExcludedFromDividends(account, isExcluded);
    }
    
    function getHolderCount() external view returns(uint256) {
        return _holders.length;
    }
}
