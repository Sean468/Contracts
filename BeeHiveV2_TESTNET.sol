// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) { return 0; }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;
    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER");
        _;
    }
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED");
        _;
    }
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }
    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA, address tokenB, uint amountADesired, uint amountBDesired,
        uint amountAMin, uint amountBMin, address to, uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token, uint amountTokenDesired, uint amountTokenMin,
        uint amountETHMin, address to, uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin, address[] calldata path,
        address to, uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin, address[] calldata path, address to,
        uint deadline
    ) external payable;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn, uint amountOutMin, address[] calldata path,
        address to, uint deadline
    ) external;
}

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit(uint256 tokenIndex) external payable;
    function process(uint256 gas) external;
    function getRewardTokenCount() external view returns (uint256);
    function setRewardTokens(IBEP20[] calldata _rewardTokens) external;
    function updateRewardTokens(IBEP20[] calldata _rewardTokens) external;
}

contract DividendDistributor is IDividendDistributor {
    using SafeMath for uint256;
    address _token;
    IDEXRouter router;
    address WBNB = 0x70499adEBB11Efd915E3b69E700c331778628707;
    IBEP20[] public rewardTokens;
    uint256[] public totalDividends;
    uint256[] public dividendsPerShare;
    uint256[] public totalDistributed;
    uint256 public dividendsPerShareAccuracyFactor = 10 ** 36;
    uint256 public minPeriod = 45 * 60;
    uint256 public minDistribution = 1 * (10 ** 13);
    struct Share {
        uint256 amount;
        uint256[] totalExcluded;
        uint256[] totalRealised;
    }
    mapping (address => Share) public shares;
    uint256 public totalShares;
    mapping (address => uint256) public shareholderClaims;
    address[] shareholders;
    mapping (address => uint256) shareholderIndexes;
    uint256 currentIndex;
    bool initialized;
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }
    modifier onlyToken() {
        require(msg.sender == _token, "Only token contract can call");
        _;
    }
    constructor (address _router) {
        router = IDEXRouter(_router != address(0) ? _router : 0x636f6407B90661b73b1C0F7e24F4C79f624d0738);
        _token = msg.sender;
    }
    function setRewardTokens(IBEP20[] calldata _rewardTokens) external override onlyToken {
        delete rewardTokens;
        delete totalDividends;
        delete dividendsPerShare;
        delete totalDistributed;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
            totalDividends.push(0);
            dividendsPerShare.push(0);
            totalDistributed.push(0);
        }
    }
    function updateRewardTokens(IBEP20[] calldata _rewardTokens) external override onlyToken {
        delete rewardTokens;
        delete totalDividends;
        delete dividendsPerShare;
        delete totalDistributed;
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
            totalDividends.push(0);
            dividendsPerShare.push(0);
            totalDistributed.push(0);
        }
    }
    function getRewardTokenCount() external view override returns (uint256) {
        return rewardTokens.length;
    }
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external override onlyToken {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }
    function deposit(uint256 tokenIndex) external override onlyToken payable {
        require(tokenIndex < rewardTokens.length, "Invalid token index");
        uint256 balanceBefore = rewardTokens[tokenIndex].balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(rewardTokens[tokenIndex]);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0, path, address(this), block.timestamp
        );
        uint256 amount = rewardTokens[tokenIndex].balanceOf(address(this)).sub(balanceBefore);
        totalDividends[tokenIndex] = totalDividends[tokenIndex].add(amount);
        if(totalShares > 0) {
            dividendsPerShare[tokenIndex] = dividendsPerShare[tokenIndex].add(
                dividendsPerShareAccuracyFactor.mul(amount).div(totalShares)
            );
        }
    }
    function setShare(address shareholder, uint256 amount) external override onlyToken {
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }
        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
            uint256 tokenCount = rewardTokens.length;
            shares[shareholder].totalExcluded = new uint256[](tokenCount);
            shares[shareholder].totalRealised = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                shares[shareholder].totalExcluded[i] = getCumulativeDividends(i, amount);
            }
        } else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }
        totalShares = totalShares.sub(shares[shareholder].amount).add(amount);
        shares[shareholder].amount = amount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            shares[shareholder].totalExcluded[i] = getCumulativeDividends(i, amount);
        }
    }
    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;
        if(shareholderCount == 0) { return; }
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();
        uint256 iterations = 0;
        while(gasUsed < gas && iterations < shareholderCount) {
            if(currentIndex >= shareholderCount){
                currentIndex = 0;
            }
            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }
            uint256 newGasLeft = gasleft();
            gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            gasLeft = newGasLeft;
            currentIndex++;
            iterations++;
        }
    }
    function shouldDistribute(address shareholder) internal view returns (bool) {
        if(shareholderClaims[shareholder] + minPeriod >= block.timestamp) return false;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if(getUnpaidEarnings(shareholder, i) > minDistribution) return true;
        }
        return false;
    }
    function distributeDividend(address shareholder) internal {
        if(shares[shareholder].amount == 0){ return; }
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 amount = getUnpaidEarnings(shareholder, i);
            if(amount > 0){
                totalDistributed[i] = totalDistributed[i].add(amount);
                rewardTokens[i].transfer(shareholder, amount);
                shareholderClaims[shareholder] = block.timestamp;
                shares[shareholder].totalRealised[i] = shares[shareholder].totalRealised[i].add(amount);
                shares[shareholder].totalExcluded[i] = getCumulativeDividends(i, shares[shareholder].amount);
            }
        }
    }
    function claimDividend() external {
        distributeDividend(msg.sender);
    }
    function getUnpaidEarnings(address shareholder, uint256 tokenIndex) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }
        uint256 shareholderTotalDividends = getCumulativeDividends(tokenIndex, shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded[tokenIndex];
        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }
        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }
    function getCumulativeDividends(uint256 tokenIndex, uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare[tokenIndex]).div(dividendsPerShareAccuracyFactor);
    }
    function addShareholder(address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }
    function removeShareholder(address shareholder) internal {
        uint256 index = shareholderIndexes[shareholder];
        shareholders[index] = shareholders[shareholders.length - 1];
        shareholderIndexes[shareholders[shareholders.length - 1]] = index;
        shareholders.pop();
    }
}

contract Beehive is IBEP20, Auth {
    using SafeMath for uint256;
    address public WBNB = 0x70499adEBB11Efd915E3b69E700c331778628707;
    address public DEAD = 0x000000000000000000000000000000000000dEaD;
    address public ZERO = 0x0000000000000000000000000000000000000000;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    uint256 public _maxTxAmount = _totalSupply;
    uint256 public _maxWalletToken = _totalSupply;
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;
    bool public blacklistMode = true;
    mapping (address => bool) public isBlacklisted;
    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;
    mapping (address => bool) isTimelockExempt;
    mapping (address => bool) isDividendExempt;
    uint256 public liquidityFee    = 0;
    uint256 public reflectionFee   = 400;
    uint256 public marketingFee    = 0;
    uint256 public devFee          = 0;
    uint256 public totalFee        = marketingFee.add(reflectionFee).add(liquidityFee).add(devFee);
    uint256 public feeDenominator  = 10000;
    uint256 public sellMultiplier  = 400;
    address public autoLiquidityReceiver;
    address public marketingFeeReceiver;
    address public devFeeReceiver;
    uint256 targetLiquidity = 100;
    uint256 targetLiquidityDenominator = 10000;
    IDEXRouter public router;
    address public pair;
    bool public tradingOpen = false;
    DividendDistributor public distributor;
    uint256 distributorGas = 500000;
    bool public buyCooldownEnabled = true;
    uint8 public cooldownTimerInterval = 1;
    mapping (address => uint) private cooldownTimer;
    bool public swapEnabled = true;
    uint256 public swapThreshold;
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }
    uint256 public rewardDistributionBatch = 1;
    uint256 public lastRewardTokenDistributed = 0;
    // --- Wrapper functions to set/update reward tokens via Beehive ---
    function setRewardTokens(IBEP20[] calldata _rewardTokens) external onlyOwner {
        distributor.setRewardTokens(_rewardTokens);
    }
    function updateRewardTokens(IBEP20[] calldata _rewardTokens) external onlyOwner {
        distributor.updateRewardTokens(_rewardTokens);
    }
    function setRewardDistributionBatch(uint256 _batch) external onlyOwner {
        rewardDistributionBatch = _batch;
    }
    // Function to update the auto-liquidity receiver address
    function setAutoLiquidityReceiver(address _receiver) external onlyOwner {
        require(_receiver != address(0), "Invalid address");
        autoLiquidityReceiver = _receiver;
    }
    // Function to update fee receivers (they can be the same)
    function setFeeReceivers(address _autoLiquidityReceiver, address _marketingFeeReceiver, address _devFeeReceiver) external onlyOwner {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        marketingFeeReceiver = _marketingFeeReceiver;
        devFeeReceiver = _devFeeReceiver;
    }
    // NEW: Set all fees to zero
    function setFeesToZero() external onlyOwner {
        liquidityFee = 0;
        reflectionFee = 0;
        marketingFee = 0;
        devFee = 0;
        totalFee = 0;
    }
    // NEW: Set standard fees: dev fee = 0.5% and reflection fee = 1.5%; liquidity and marketing fees are zero.
    function setStandardFees() external onlyOwner {
        liquidityFee = 0;
        marketingFee = 0;
        reflectionFee = 150; // 1.5% of 10000
        devFee = 50;         // 0.5% of 10000
        totalFee = liquidityFee.add(reflectionFee).add(marketingFee).add(devFee);
    }
    // NEW: Mint new tokens to a specified address
    function mint(address to, uint256 amount) external onlyOwner {
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        emit Transfer(address(0), to, amount);
    }
    constructor (
        string memory tokenName, 
        string memory tokenSymbol, 
        uint8 tokenDecimals, 
        uint256 tokenTotalSupply
    ) Auth(msg.sender) {
        _name = tokenName;
        _symbol = tokenSymbol;
        _decimals = tokenDecimals; 
        _totalSupply = tokenTotalSupply.mul(10**uint256(tokenDecimals));
        _maxTxAmount = _totalSupply;
        _maxWalletToken = _totalSupply;
        swapThreshold = _totalSupply.mul(50).div(35500);
        router = IDEXRouter(0x636f6407B90661b73b1C0F7e24F4C79f624d0738);
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = uint256(-1);
        distributor = new DividendDistributor(address(router));
        autoLiquidityReceiver = msg.sender;
        marketingFeeReceiver = msg.sender;
        devFeeReceiver = msg.sender;
        isFeeExempt[msg.sender] = true;
        isTxLimitExempt[msg.sender] = true;
        isTimelockExempt[msg.sender] = true;
        isTimelockExempt[DEAD] = true;
        isTimelockExempt[address(this)] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[DEAD] = true;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
    receive() external payable { }
    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external view override returns (uint8) { return _decimals; }
    function symbol() external view override returns (string memory) { return _symbol; }
    function name() external view override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function approveMax(address spender) external returns (bool) {
        return approve(spender, uint256(-1));
    }
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != uint256(-1)){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }
        return _transferFrom(sender, recipient, amount);
    }
    function setMaxWalletPercent_base1000(uint256 maxWallPercent_base1000) external onlyOwner {
        _maxWalletToken = (_totalSupply.mul(maxWallPercent_base1000)) / 1000;
    }
    function setMaxTxPercent_base1000(uint256 maxTXPercentage_base1000) external onlyOwner {
        _maxTxAmount = (_totalSupply.mul(maxTXPercentage_base1000)) / 1000;
    }
    function setTxLimit(uint256 amount) external authorized {
        _maxTxAmount = amount;
    }
    function updateRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Router address cannot be zero");
        require(newRouter != address(router), "Router already set");
        router = IDEXRouter(newRouter);
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = uint256(-1);
        emit RouterUpdated(newRouter);
    }
    event RouterUpdated(address newRouter);
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(inSwap){ return _basicTransfer(sender, recipient, amount); }
        if(!authorizations[sender] && !authorizations[recipient]){
            require(tradingOpen, "Trading not open yet");
        }
        if(blacklistMode){
            require(!isBlacklisted[sender] && !isBlacklisted[recipient], "Blacklisted");    
        }
        if (!authorizations[sender] && recipient != address(this) && recipient != DEAD && recipient != pair &&
           recipient != marketingFeeReceiver && recipient != devFeeReceiver && recipient != autoLiquidityReceiver) {
            uint256 heldTokens = balanceOf(recipient);
            require(heldTokens.add(amount) <= _maxWalletToken, "Total Holding limited");
        }
        if (sender == pair && buyCooldownEnabled && !isTimelockExempt[recipient]) {
            require(cooldownTimer[recipient] < block.timestamp, "Cooldown active");
            cooldownTimer[recipient] = block.timestamp + cooldownTimerInterval;
        }
        checkTxLimit(sender, amount);
        if(shouldSwapBack()){ swapBack(); }
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        // Burn 1% on every transaction if fees apply
        uint256 burnAmount = 0;
        if(shouldTakeFee(sender)) {
            burnAmount = amount.mul(1).div(100);
            amount = amount.sub(burnAmount);
            _balances[DEAD] = _balances[DEAD].add(burnAmount);
            emit Transfer(sender, DEAD, burnAmount);
        }
        uint256 amountReceived = shouldTakeFee(sender) ? takeFee(sender, amount, (recipient == pair)) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);
        if(!isDividendExempt[sender]) {
            try distributor.setShare(sender, _balances[sender]) {} catch {}
        }
        if(!isDividendExempt[recipient]) {
            try distributor.setShare(recipient, _balances[recipient]) {} catch {} 
        }
        try distributor.process(distributorGas) {} catch {}
        emit Transfer(sender, recipient, amountReceived);
        return true;
    }
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }
    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
    }
    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }
    function takeFee(address sender, uint256 amount, bool isSell) internal returns (uint256) {
        uint256 multiplier = isSell ? sellMultiplier : 100;
        uint256 feeAmount = amount.mul(totalFee).mul(multiplier).div(feeDenominator.mul(100));
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        return amount.sub(feeAmount);
    }
    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair && !inSwap && swapEnabled && _balances[address(this)] >= swapThreshold;
    }
    function clearStuckBalance(uint256 amountPercentage) external authorized {
        uint256 amountBNB = address(this).balance;
        payable(marketingFeeReceiver).transfer(amountBNB.mul(amountPercentage).div(100));
    }
    function clearStuckBalance_sender(uint256 amountPercentage) external authorized {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer(amountBNB.mul(amountPercentage).div(100));
    }
    function set_sell_multiplier(uint256 Multiplier) external onlyOwner {
        sellMultiplier = Multiplier;        
    }
    function tradingStatus(bool _status) public onlyOwner {
        tradingOpen = _status;
    }
    function cooldownEnabled(bool _status, uint8 _interval) public onlyOwner {
        buyCooldownEnabled = _status;
        cooldownTimerInterval = _interval;
    }
    function swapBack() internal swapping {
        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
        uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(totalFee).div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WBNB;
        uint256 balanceBefore = address(this).balance;
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap, 0, path, address(this), block.timestamp
        );
        uint256 amountBNB = address(this).balance.sub(balanceBefore);
        uint256 totalBNBFee = totalFee.sub(dynamicLiquidityFee.div(2));
        uint256 amountBNBLiquidity = amountBNB.mul(dynamicLiquidityFee).div(totalBNBFee).div(2);
        uint256 amountBNBReflection = amountBNB.mul(reflectionFee).div(totalBNBFee);
        uint256 amountBNBMarketing = amountBNB.mul(marketingFee).div(totalBNBFee);
        uint256 amountBNBDev = amountBNB.mul(devFee).div(totalBNBFee);
        uint256 tokenCount = distributor.getRewardTokenCount();
        if(tokenCount > 0 && amountBNBReflection > 0) {
            uint256 batch = rewardDistributionBatch;
            if(batch > tokenCount) { batch = tokenCount; }
            uint256 allocationPerToken = amountBNBReflection.div(tokenCount);
            for(uint256 i = 0; i < batch; i++){
                uint256 index = (lastRewardTokenDistributed + i) % tokenCount;
                try distributor.deposit{value: allocationPerToken}(index) {} catch {}
            }
            lastRewardTokenDistributed = (lastRewardTokenDistributed + batch) % tokenCount;
        }
        (bool tmpSuccess,) = payable(marketingFeeReceiver).call{value: amountBNBMarketing, gas: 30000}("");
        (tmpSuccess,) = payable(devFeeReceiver).call{value: amountBNBDev, gas: 30000}("");
        tmpSuccess = false;
        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountBNBLiquidity}(
                address(this), amountToLiquify, 0, 0, autoLiquidityReceiver, block.timestamp
            );
            emit AutoLiquify(amountBNBLiquidity, amountToLiquify);
        }
    }
    function setIsDividendExempt(address holder, bool exempt) external authorized {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, _balances[holder]);
        }
    }
    function enable_blacklist(bool _status) public onlyOwner {
        blacklistMode = _status;
    }
    function manage_blacklist(address[] calldata addresses, bool status) public onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            isBlacklisted[addresses[i]] = status;
        }
    }
    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }
    function setIsTxLimitExempt(address holder, bool exempt) external authorized {
        isTxLimitExempt[holder] = exempt;
    }
    function setFees(uint256 _liquidityFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _devFee, uint256 _feeDenominator) external authorized {
        liquidityFee = _liquidityFee;
        reflectionFee = _reflectionFee;
        marketingFee = _marketingFee;
        devFee = _devFee;
        totalFee = _liquidityFee.add(_reflectionFee).add(_marketingFee).add(_devFee);
        feeDenominator = _feeDenominator;
        require(totalFee < feeDenominator.div(3), "Fees cannot be more than 33%");
    }
    function setSwapBackSettings(bool _enabled, uint256 _amount) external authorized {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }
    function setTargetLiquidity(uint256 _target, uint256 _denominator) external authorized {
        targetLiquidity = _target;
        targetLiquidityDenominator = _denominator;
    }
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external authorized {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }
    function setDistributorSettings(uint256 gas) external authorized {
        require(gas < 750000);
        distributorGas = gas;
    }
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }
    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
    }
    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }
    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);
}
