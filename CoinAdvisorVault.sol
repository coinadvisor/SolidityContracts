pragma solidity ^0.4.21;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        require(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }
}


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title BurnableCADVToken interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract BurnableCADVToken is ERC20 {

    uint8 public decimals = 18;
    string public name;
    string public symbol;
    
    /**
     * @dev set the amount of tokens that an owner allowed to a spender.
     *  
     * This function is disabled because using it is risky, so a revert()
     * is always called as the first line of code.
     * Instead of this function, use increaseApproval or decreaseApproval.
     * 
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to increase the allowance by.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != _spender);
        require(_value != _value);
        revert();
    }
    
    function increaseApproval(address _spender, uint _addedValue) public returns (bool);
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool);
    function multipleTransfer(address[] _tos, uint256 _value) public returns (bool);
    function burn(uint256 _value) public;
    event Burn(address indexed burner, uint256 value);
    
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    
    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    function constructor() public {
        owner = msg.sender;
    }
    
    
    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    
    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}


/**
 * @title Controlled CrowdSale
 */
contract ControlledCrowdSale {
    using SafeMath for uint256;
    
    mapping (address => uint256) public deposited;
    mapping (address => bool) public unboundedLimit;
    
    uint256 public maxPerUser = 5 ether;
    uint256 public minPerUser = 1 ether / 1000;
    
    
    modifier controlledDonation() {
        require(msg.value >= minPerUser);
        deposited[msg.sender] = deposited[msg.sender].add(msg.value);
        require(maxPerUser >= deposited[msg.sender] || unboundedLimit[msg.sender]);
        _;
    }

}


/**
 * @title CoinAdvisorPreIco
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the money if crowdsale fails,
 * and forwarding it to a beneficiary if crowdsale is successful.
 */
contract CoinAdvisorVault is Ownable, ControlledCrowdSale {
    using SafeMath for uint256;
    enum State { Active, Refunding, Completed }
    
    struct Phase {
        uint expireDate;
        uint256 maxAmount;
        bool maxAmountEnabled;
        uint rate;
        bool locked;
    }

//=== properties =============================================
    Phase[] public phases;
    uint256 lastActivePhase;
    State state;
    uint256 public goal;
    address public beneficiary;
    BurnableCADVToken public token;
    uint256 public refunduingStartDate;
    
    uint256 public totTokensBooked;
    mapping (address => uint256) public tokensBooked;

//=== events ==================================================
    event PreIcoClosed(string message, address crowdSaleClosed);
    event RefundsEnabled();
    event Refunded(address indexed beneficiary, uint256 weiAmount);
    event PreIcoStarted(string message, address crowdSaleStarted);

//=== constructor =============================================
    function constructor(address _beneficiary, address _token, uint256 _goal, uint256 _refunduingStartDate) public {
        require(_beneficiary != address(0));
        beneficiary = _beneficiary;
        token = BurnableCADVToken(_token);
        phases.push(Phase(0, 0, false, 0, false));
        lastActivePhase = 0;
        goal = _goal * 1 ether;
        state = State.Active;
        refunduingStartDate = _refunduingStartDate;
        totTokensBooked = 0;
    }


    /**
     * 
     *
     */ 
    function isPhaseValid(uint256 index) public view returns (bool) {
        return phases[index].expireDate >= now && (!phases[index].maxAmountEnabled || phases[index].maxAmount > minPerUser);
    } 
    
    
    /**
     * 
     *
     */
    function currentPhaseId() public view returns (uint256) {
        uint256 index = lastActivePhase;
        while(index < phases.length-1 && !isPhaseValid(index)) {
            index = index +1;
        }
        return index;
    }
    
    
    /**
     * 
     *
     */
    function addPhases(uint expireDate, uint256 maxAmount, bool maxAmountEnabled, uint rate, bool locked) onlyOwner public {
        phases.push(Phase(expireDate, maxAmount, maxAmountEnabled, rate, locked));
    }
    
    
    /**
     * 
     *
     */
    function resetPhases(uint expireDate, uint256 maxAmount, bool maxAmountEnabled, uint rate, bool locked) onlyOwner public {
        require(!phases[currentPhaseId()].locked);
        phases.length = 0;
        lastActivePhase = 0;
        addPhases(expireDate, maxAmount, maxAmountEnabled, rate, locked);
    }
    
    
    /**
     * 
     *
     */
    function () controlledDonation public payable {
        require(state != State.Refunding);
        uint256 phaseId = currentPhaseId();
        require(isPhaseValid(phaseId)); //cannot process, throws
        
        uint256 toBuy = msg.value;
        uint256 toTransfer = 0;
        while(toBuy > 0) {
            if (!isPhaseValid(phaseId)) {
                require(toTransfer > 0); // the phase is not vaid and there's no tokens to transfer: throw!
                msg.sender.transfer(toBuy); // there are tokens to transfer, but no further valid phases, refund the surplus.
                deposited[msg.sender] = deposited[msg.sender].sub(toBuy);
                toBuy = 0;
            } else if (phases[phaseId].maxAmountEnabled) {
                if (phases[phaseId].maxAmount >= toBuy) {
                    phases[phaseId].maxAmount = phases[phaseId].maxAmount.sub(toBuy);
                    toTransfer = toTransfer.add(toBuy.mul(phases[phaseId].rate));
                    toBuy = 0;
                } else {
                    toTransfer = toTransfer.add(phases[phaseId].maxAmount.mul(phases[phaseId].rate));
                    toBuy = toBuy.sub(phases[phaseId].maxAmount);
                    phases[phaseId].maxAmount = 0;
                    phaseId = currentPhaseId();
                }
            } else {
                
            }
        }
        require(toTransfer > 0);
        if (state == State.Completed) {
            require(token.transfer(msg.sender, toTransfer));
        } else {
            tokensBooked[msg.sender] = tokensBooked[msg.sender].add(toTransfer);
            totTokensBooked = totTokensBooked.add(toTransfer);
        }
        lastActivePhase = phaseId;
    }
    
    /**
     * 
     *
     */
    function releaseBookedTokensTo(address[] _addrList) public returns (bool) {
        require(msg.sender == owner || state == State.Completed);
        for (uint256 i=0; i<_addrList.length; i++) {
            uint256 toTransfer = tokensBooked[_addrList[i]];
            tokensBooked[_addrList[i]] = 0;
            require(token.transfer(_addrList[i], toTransfer));
            totTokensBooked = totTokensBooked.sub(toTransfer);
        }
        return true;
    }
    
    /**
     * 
     *
     */
    function retrieveFounds() onlyOwner public {
        require(state == State.Completed || (state == State.Active && address(this).balance >= goal));
        state = State.Completed;
        beneficiary.transfer(address(this).balance);
    }
    
    
    /**
     * 
     *
     */
    function startRefunding() public {
        require(state == State.Active);
        require(address(this).balance < goal);
        require(refunduingStartDate < now);
        state = State.Refunding;
        emit RefundsEnabled();
    }
    
    
    /**
     * 
     *
     */
    function forceRefunding() onlyOwner public {
        require(state == State.Active);
        state = State.Refunding;
        emit RefundsEnabled();
    }
    
    
    /**
     * 
     *
     */
    function refund(address investor) public {
        require(state == State.Refunding);
        require(deposited[investor] > 0);
        
        uint256 depositedValue = deposited[investor];
        deposited[investor] = 0;
        investor.transfer(depositedValue);
        emit Refunded(investor, depositedValue);
    }
    
    /**
     * 
     *
     */
    function availableTokens() public view returns (uint256) {
        return token.balanceOf(this).sub(totTokensBooked);
    }
    /**
     * 
     *
     */
    function retrieveCadvsLeftInRefunding() onlyOwner public {
        require(availableTokens() > 0);
        require(token.transfer(beneficiary, availableTokens()));
    }
    
    /**
     * 
     *
     */
    function gameOver() onlyOwner public {
        require(!isPhaseValid(currentPhaseId()));
        require(state == State.Completed || (state == State.Active && address(this).balance >= goal));
        require(token.transfer(beneficiary, availableTokens()));
        selfdestruct(beneficiary);
    }
    
    
    /**
     * 
     *
     */
    function setUnboundedLimit(address _investor, bool _state) onlyOwner public {
        require(_investor != address(0));
        unboundedLimit[_investor] = _state;
    }

    
    function currentState() public view returns (string) {
        if (state == State.Active) {
            return "Active";
        }
        if (state == State.Completed) {
            return "Completed";
        }
        if (state == State.Refunding) {
            return "Refunding";
        }
    }
    
    
    function tokensOnSale() public view returns (uint256) {
        uint256 i = currentPhaseId();
        if (isPhaseValid(i)) {
            return phases[i].maxAmountEnabled ? phases[i].maxAmount : availableTokens();
        } else {
            return 0;
        }
    }

    
}
