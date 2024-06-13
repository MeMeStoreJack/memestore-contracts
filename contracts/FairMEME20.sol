// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IReferrerStorage.sol";
contract FairMEME20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256  public totalSupply;

    address payable public tradeFeeReceiver;
    address payable public protocolReceiver;
    IReferrerStorage public referrerStorage;
    uint public tradeStep = 0;

    struct MintConfig{
        uint256 mintSupply;
        uint256 mintPrice;
        uint256 singleMintMin;
        uint256 singleMintMax;
        uint256 mintMax;
        uint256 endTimestamp;
        uint256 liquidityPrice;
    }

    MintConfig  public mintConfig;

    struct TradeConfig{
        IUniswapV2Router01 swapRouter;
        uint256 targetAmount;
    }

    TradeConfig  public tradeConfig;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping(address => uint256)) public allowance;
    mapping (address => uint256) public nonces;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event FairMint(address indexed from, uint256 amount);
    event AddLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 timestamp
    );

    event TradeStep(uint256 tradeStep);
    constructor(string memory _name, string memory _symbol, uint8 _decimals, MintConfig memory _mintConfig, TradeConfig memory _tradeConfig, address payable _protocolReceiver) {
        require(_protocolReceiver != address(0), "zero address");
        require(_mintConfig.endTimestamp > block.timestamp, "endTimestamp error");
        require(address(_tradeConfig.swapRouter) != address(0), "zero address");

        protocolReceiver = _protocolReceiver;
        protocolReceiver = _protocolReceiver;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        mintConfig = _mintConfig;

        emit TradeStep(tradeStep);

        tradeConfig = _tradeConfig;
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes('1')), chainId, address(this)));
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

    function fairMint(uint256 amount) public payable  {
        require(tradeStep == 0, "not fair mint");
        require(amount >= mintConfig.singleMintMin, "too low");
        require(amount <= mintConfig.singleMintMax, "too big");

        require(balanceOf[msg.sender] + amount <= mintConfig.mintMax, "total exceed mintMax");
        require(totalSupply + amount <= mintConfig.mintSupply, "total exceed mintSupply");

        require(msg.value * 1 ether >= amount * mintConfig.mintPrice, "insufficient pay");

        require(block.timestamp <= mintConfig.endTimestamp, "Expired");

        _mint(msg.sender,amount);

        protocolReceiver.transfer(msg.value*5/100);

        if (totalSupply + mintConfig.singleMintMin > mintConfig.mintSupply){
            tradeStep = 2;
            emit TradeStep(2);

            uint poolTokenAmount = (address(this).balance * 1 ether) / mintConfig.liquidityPrice;
            _mint(address(this), poolTokenAmount);

            _addLiquidity(poolTokenAmount,address(this).balance);
        }

        emit FairMint(msg.sender,amount);
    }

    function createPoolWithExpired() public {
        require(tradeStep == 0, "not fair mint");
        require(block.timestamp > mintConfig.endTimestamp, "not expired");
        tradeStep = 2;
        emit TradeStep(2);

        uint poolTokenAmount = (address(this).balance * 1 ether) / mintConfig.liquidityPrice;
        _mint(address(this), poolTokenAmount);

        _addLiquidity(poolTokenAmount,address(this).balance);
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