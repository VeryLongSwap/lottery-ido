pragma solidity ^0.8.23;

/* これは適当に0.8.23に改修しただけなので本番では使わないこと */
/* これは適当に0.8.23に改修しただけなので本番では使わないこと */
/* これは適当に0.8.23に改修しただけなので本番では使わないこと */
/* これは適当に0.8.23に改修しただけなので本番では使わないこと */
/* これは適当に0.8.23に改修しただけなので本番では使わないこと */
/* これは適当に0.8.23に改修しただけなので本番では使わないこと */

contract WETH9 {
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;
    uint public totalSupply = 0;
    address public owner;
    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }
    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address newOwner) public isOwner {
        owner = newOwner;
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function mint(uint _value) public isOwner {
        balanceOf[msg.sender] += _value;
        totalSupply += _value;
        emit Deposit(msg.sender, _value);
    }
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        (bool success, ) = payable(msg.sender).call{value: wad}('');
        require(success, "transfer failed");
        totalSupply -= wad;
        emit Withdrawal(msg.sender, wad);
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
    public
    returns (bool)
    {
        require(balanceOf[src] >= wad);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}
