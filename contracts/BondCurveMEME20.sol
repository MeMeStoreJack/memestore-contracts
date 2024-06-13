// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IReferrerStorage.sol";

contract BondCurveMEME20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256  public totalSupply;

    address payable public tradeFeeReceiver;
    address payable public protocolReceiver;
    IReferrerStorage public referrerStorage;
    uint public tradeStep = 0;
    uint public lastTokenPrice = 0;

    struct TradeConfig{
        IUniswapV2Router01 swapRouter;
        uint256 targetAmount;
        uint256 tradeA;
        uint256 initBuyValue; // eth value for first buy when deploy
        uint256 initBuyMaxPercent;
    }

    TradeConfig  public tradeConfig;

    struct TradeInfo{
        address referrer;
        uint256 referrerAmount;
        address upReferrer;
        uint256 upReferrerAmount;
        uint256 feeValue;
        uint256 remainAmount;
    }

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping(address => uint256)) public allowance;
    mapping (address => uint256) public nonces;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event AddLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 timestamp
    );

    event TradeStep(uint256 tradeStep);
    event Buy(address sender, uint256 value, uint256 tokenAmount, uint lastTokenPrice, TradeInfo tradeInfo);
    event Sell(address sender, uint256 value, uint256 tokenAmount, uint lastTokenPrice, TradeInfo tradeInfo);
    constructor(string memory _name, string memory _symbol, uint8 _decimals, TradeConfig memory _tradeConfig, address payable _tradeFeeReceiver, address payable _protocolReceiver, IReferrerStorage _referrerStorage, address issuer) payable {
        require(_tradeFeeReceiver != address(0), "zero address");
        require(_protocolReceiver != address(0), "zero address");
        require(address(_referrerStorage) != address(0), "zero address");
        require(address(_tradeConfig.swapRouter) != address(0), "zero address");

        tradeFeeReceiver = _tradeFeeReceiver;
        protocolReceiver = _protocolReceiver;
        referrerStorage = _referrerStorage;
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        tradeStep = 1;

        emit TradeStep(1);

        _mint(address(this),10**27); // 1b

        tradeConfig = _tradeConfig;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes('1')), chainId, address(this)));
        if (_tradeConfig.initBuyValue > 0) {
            require(issuer != address(0), "zero issuer address");
            require(msg.value == _tradeConfig.initBuyValue, "insufficient eth");
            require(_tradeConfig.initBuyMaxPercent <= 1000, "invalid percent");
            require(_tradeConfig.initBuyValue * 1000 <= _tradeConfig.targetAmount * _tradeConfig.initBuyMaxPercent, "exceed max init_buy percent");// initBuyValue/targetAmount <= initBuyMaxPercent/1000
            _buy(issuer);
        }
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(tradeStep == 2, "not transfer");
        balanceOf[msg.sender] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(tradeStep == 2, "not transfer");
        uint256 allowed = allowance[from][msg.sender];

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'EXPIRED');

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes('1')), chainId, address(this)));

        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR,
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
                )
            );
            address recoveredAddress = ecrecover(digest, v, r, s);
            require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNATURE');
            allowance[recoveredAddress][spender] = value;
        }
        emit Approval(owner, spender, value);
    }

    function buy() public payable  {
        _buy(msg.sender);
    }

    function _buy(address sender) internal {
        require(tradeStep == 1, "not trade");

        TradeInfo memory tradeInfo =  _splitFee(msg.value);

        uint256 tokenAmount = (tradeInfo.remainAmount * (balanceOf[address(this)])) /
                (((address(this).balance) + tradeConfig.tradeA));
        lastTokenPrice = (tradeInfo.remainAmount * 1 ether) / tokenAmount;

        _transfer(address(this),sender,tokenAmount);

        if(address(this).balance >= tradeConfig.targetAmount){
            tradeStep = 2;
            emit TradeStep(2);

            protocolReceiver.transfer(address(this).balance*5/100);
            uint poolTokenAmount  = ((address(this).balance) * 1 ether) / lastTokenPrice;

            if (balanceOf[address(this)] > poolTokenAmount) {
                _burn(address(this), (balanceOf[address(this)] - poolTokenAmount));
            } else {
                _mint(address(this), (poolTokenAmount - balanceOf[address(this)]));
            }
            _addLiquidity(poolTokenAmount,address(this).balance);
            
        }

        emit Buy(sender, msg.value, tokenAmount, lastTokenPrice, tradeInfo);
    }

    function sell(uint256 amount) external{
        require(tradeStep == 1, "not trade");
        require(balanceOf[msg.sender] >= amount, "exceed balance");

        uint256 ethAmount = (amount * (address(this).balance + tradeConfig.tradeA)) /
            ((((balanceOf[address(this)]) + amount )));

        lastTokenPrice = (ethAmount * 1 ether) / amount;

        require(ethAmount > 0, "Sell amount too low");
        require(
            address(this).balance >= ethAmount,
            "Insufficient ETH in reserves"
        );

        TradeInfo memory tradeInfo = _splitFee(ethAmount);

        _transfer(msg.sender,address(this),amount);

        payable(msg.sender).transfer(tradeInfo.remainAmount);

        emit Sell(msg.sender, tradeInfo.remainAmount, amount, lastTokenPrice,tradeInfo);
    }

    function getAmountOut(uint256 value, bool _buy)public view returns (uint256){
         if (_buy) {
            return (value * (balanceOf[address(this)])) /
                ((address(this).balance) +value+ tradeConfig.tradeA);
        } else {
             return (value * (address(this).balance + tradeConfig.tradeA)) /
                 ((balanceOf[address(this)])+value);
        }
    }

    function getContactBalance()public view returns (uint256){
        return address(this).balance;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        require(
            balanceOf[from] >= value,
            "ERC20: transfer amount exceeds balance"
        );

        unchecked {
            balanceOf[from] = balanceOf[from] - value;
        }

        if (to == address(0)) {
            unchecked {
                totalSupply -= value;
            }
        } else {
            unchecked {
                balanceOf[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;

        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;

        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function _splitFee(uint amount) internal returns(TradeInfo memory tradeInfo)  {
        uint256 feeValue = (amount * 1) / 100;
        uint256 shareValue = (amount * 5) / 1000;

        tradeFeeReceiver.transfer(feeValue);

        // share invite bonus
        (address referrer, address upReferrer) = referrerStorage.getReferrers(msg.sender);
        if (referrer != address(0)){
            payable(referrer).transfer((amount * 3) / 1000);
        }else{
            tradeFeeReceiver.transfer((amount * 3) / 1000);
        }
        if (upReferrer != address(0)){
            payable(upReferrer).transfer((amount * 2) / 1000);
        }else{
            tradeFeeReceiver.transfer((amount * 2) / 1000);
        }

        tradeInfo.feeValue = feeValue;
        tradeInfo.referrer = referrer;
        tradeInfo.upReferrer = upReferrer;
        tradeInfo.referrerAmount = (amount * 3) / 1000;
        tradeInfo.upReferrerAmount = (amount * 2) / 1000;
        tradeInfo.remainAmount = amount - feeValue - shareValue;
        return tradeInfo;
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        allowance[address(this)][address(tradeConfig.swapRouter)] = tokenAmount;
        tradeConfig.swapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(0),
            block.timestamp
        );
        emit AddLiquidity(tokenAmount, ethAmount, block.timestamp);
    }

    receive() external payable {}
}