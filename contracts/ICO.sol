/**
  ______      __           __        __            
 /_  __/___ _/ /__  ____  / /_____  / /_____  ____ 
  / / / __ `/ / _ \/ __ \/ __/ __ \/ //_/ _ \/ __ \
 / / / /_/ / /  __/ / / / /_/ /_/ / ,< /  __/ / / /
/_/  \__,_/_/\___/_/ /_/\__/\____/_/|_|\___/_/ /_/ 
*/

pragma solidity ^0.4.18;

import './Owned.sol';
import './Talentoken.sol';

contract ICO is Owned {
    uint8 public decimals = 8;
    uint256 private TOKEN_UNIT = 10 ** uint256(decimals);

    // status variable
    uint256 public softcap = 2300 ether;    //Includes minimum development and marketing costs
    uint256 public hardcap = 15500 ether;

    uint256 public marketingcap = 300 ether;

    uint256 public bottom = 0.15 ether;
    uint256 public top = 100 ether;
    
    uint256 public deadline = 10 weeks;

    uint256 public price;   // base price
    uint256 public ICOTokenAmount = 55000000 * TOKEN_UNIT;
    uint256 public soldToken;
    uint256 public fundedEth;

    uint256 public startTime;
    Talentoken public tokenReward;

    // flags
    bool public softcapReached;
    bool public hardcapReached;
    bool public ICOproceeding; 

    struct InvestorProperty {
        uint256 payment;    // paid ETH
        uint256 reserved;   // received token
        bool withdrawed;    // withdrawl flag
    }

    mapping (address => InvestorProperty) public InvestorsProperty; //asset information of investors
    mapping (uint => address) public InvestorsAddress;
    uint public index;
    // event notification
    event ICOStart(uint hardcap, uint deadline, uint tokenAmount, address beneficiary);
    event ReservedToken(address backer, uint amount, uint token);
    event CheckGoalReached(address beneficiary, uint hardcap, uint amountRaised, bool reached, uint raisedToken);
    event WithdrawalToken(address addr, uint amount, bool result);
    event WithdrawalEther(address addr, uint amount, bool result);

    // constructor
    function ICO (Talentoken _addressOfTokenContract) public {
        price = 16050 ether / ICOTokenAmount;
        tokenReward = Talentoken(_addressOfTokenContract);

        startTime = tokenReward.startTime();
        deadline = startTime + deadline;
    }

    // anonymous function for receive ETH
    function () public payable {
        // exception handling before or after expiration
        require (ICOproceeding && now < deadline);

        // limit maximum gas price
        require (tx.gasprice <= 50000000000 wei);

        // received Ether and to-be-sold token
        uint256 amount = msg.value;
        uint256 token = amount / price;

        require (token != 0);
        require (amount >= bottom);
        require (amount <= top);

        if (fundedEth <= marketingcap) {
            token = token * 15 / 10;
        } else {
            if (fundedEth <= softcap) {
                token = token * 12 / 10;
            }
        }

        if (soldToken + token < ICOTokenAmount) {
            InvestorsAddress[index] = msg.sender;
            index++;

            InvestorsProperty[msg.sender].payment += amount;
            InvestorsProperty[msg.sender].reserved += token;
            soldToken += token;
            fundedEth += amount;
            if (fundedEth > softcap) {
                softcapReached = true;
            }
            ReservedToken(msg.sender, amount, token);
        } else { 
            token = ICOTokenAmount - soldToken;
            amount = token * price;

            InvestorsAddress[index] = msg.sender;
            index++;

            InvestorsProperty[msg.sender].payment += amount;
            InvestorsProperty[msg.sender].reserved += token;
            soldToken += token;
            fundedEth += amount;

            uint256 returnSenderAmount = msg.value - amount;        // Return the difference when hardcap is exceeded
            if (returnSenderAmount > 0) {
                msg.sender.transfer(returnSenderAmount);
            }

            ReservedToken(msg.sender, amount, token);

            softcapReached = true;
            hardcapReached = true;
            ICOproceeding = false;

            CheckGoalReached(owner, hardcap, this.balance, softcapReached, soldToken);
        }
    }

    // start when the # of token is more than cap
    function start() public onlyOwner {
        require (price != 0);
        require (startTime != 0);
        require (tokenReward != address(0));
        
        if (tokenReward.balanceOf(this) >= ICOTokenAmount) {
            ICOproceeding = true;
            ICOStart(hardcap, deadline, ICOTokenAmount, owner);
        }
    }

    function addStartTime(uint _time) public onlyOwner {
        startTime += _time;
    }

    function subStartTime(uint _time) public onlyOwner {
        startTime -= _time;    
    }

     function addDeadTime(uint _time) public onlyOwner {
        deadline += _time;
    }

    function subDeadTime(uint _time) public onlyOwner {
        deadline -= _time;    
    }

    // function for check remaining time, diff from cap
    function getRemainingTimeEthToken() public constant returns(uint min, uint shortage, uint remainToken) {
        if (now < deadline) {
            min = (deadline - now) / (1 minutes);
        }
        shortage = (hardcap - fundedEth) / (1 ether);
        remainToken = ICOTokenAmount - soldToken;
    }

    // withdrawl function for owner
    // available when softcap reached
    function withdrawalOwner() public onlyOwner {
        if (now > deadline) {
            ICOproceeding = false;
        }

        if (ICOproceeding) {
            if (softcapReached) {
                uint amount = this.balance;
                if (amount > 0) {
                    bool ok = msg.sender.call.value(amount)();
                    WithdrawalEther(msg.sender, amount, ok);
                }
            } else {
                uint256 withdrawnAmount = fundedEth - this.balance;
                if (withdrawnAmount <= marketingcap) {
                    if (withdrawnAmount + this.balance > marketingcap) {
                        bool marketingOk = msg.sender.call.value(marketingcap - withdrawnAmount)();
                        WithdrawalEther(msg.sender, marketingcap - withdrawnAmount, marketingOk);
                    } else {
                        bool marketingOk2 = msg.sender.call.value(this.balance)();
                        WithdrawalEther(msg.sender, this.balance, marketingOk2);
                    }
                } 
            }
        } else {
            if (softcapReached) { 
                uint amount2 = this.balance;
                if (amount2 > 0) {
                    bool ok2 = msg.sender.call.value(amount2)();
                    WithdrawalEther(msg.sender, 2, ok2);
                }
                uint val = ICOTokenAmount - soldToken;
                if (val > 0) {
                    tokenReward.transfer(msg.sender, ICOTokenAmount - soldToken);
                    WithdrawalToken(msg.sender, val, true);
                }
            } else {
                uint val2 = tokenReward.balanceOf(this);
                tokenReward.transfer(msg.sender, val2);
                WithdrawalToken(msg.sender, val2, true);
            }
        }
    }

    function withdrawalAllInvester() public onlyOwner {
         if (now > deadline) {
            ICOproceeding = false;
        }

        require (!ICOproceeding);

        if (softcapReached) {
            for (uint i = 0; i < index; i++) {
                address investerAddress = InvestorsAddress[i];

                if (InvestorsProperty[investerAddress].reserved > 0 && InvestorsProperty[investerAddress].withdrawed != true) {
                    tokenReward.transfer(investerAddress, InvestorsProperty[investerAddress].reserved);
                    InvestorsProperty[investerAddress].withdrawed = true;
                }
            }
        } else {
            uint re = this.balance;
            for (uint i2 = 0; i2 < index; i2++) {
                address investerAddress2 = InvestorsAddress[i2];

                if (InvestorsProperty[investerAddress2].payment > 0 && InvestorsProperty[investerAddress2].withdrawed != true) {
                    uint returnEth = InvestorsProperty[investerAddress2].payment*re/fundedEth;
                    if (investerAddress2.call.value(returnEth)()) {
                        InvestorsProperty[investerAddress2].withdrawed = true;
                    }
                }
            }
        }
    }

    // withdrawl function for investors
    function withdrawal() public {
        if (now > deadline) {
            ICOproceeding = false;
        }

        require (!ICOproceeding);
        require (!InvestorsProperty[msg.sender].withdrawed);

        // when softcap reached: tokens
        // else: ETH
        if (softcapReached) {
            if (InvestorsProperty[msg.sender].reserved > 0) {
                tokenReward.transfer(msg.sender, InvestorsProperty[msg.sender].reserved);
                InvestorsProperty[msg.sender].withdrawed = true;
                WithdrawalToken(
                    msg.sender,
                    InvestorsProperty[msg.sender].reserved,
                    InvestorsProperty[msg.sender].withdrawed
                );
            }
        } else {
            if (InvestorsProperty[msg.sender].payment > 0) {
                uint returnEth = InvestorsProperty[msg.sender].payment*this.balance/fundedEth;
                if (msg.sender.call.value(returnEth)()) {
                    InvestorsProperty[msg.sender].withdrawed = true;
                }
                WithdrawalEther(
                    msg.sender,
                    InvestorsProperty[msg.sender].payment,
                    InvestorsProperty[msg.sender].withdrawed
                );
            }
        }
    }
} 
