
pragma solidity ^0.6.9;
// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }
}

// SPDX-License-Identifier: SimPL-2.0
//"m1.1.0releasing";
pragma solidity ^0.6.9;
pragma experimental ABIEncoderV2;

// pragma solidity >=0.5.0;


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

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }
}

contract Lacar {
    using SafeMath for uint256;
    struct Parent{
        address parentAddr;
        bool isUsed;
    }
    struct UserPacket{
        uint256 sentAmount;
        uint256 recoUsers;
        //total back amount
        uint256 backAmount;
        //remain back amount
        uint256 remainBackAmount;
        //receive red packet
        uint256 getAmount;
        //
        uint256 canSendAmount;
    }
    struct RedPacket{
        address userAddress;
        uint256 sentAmount;
        uint256 remainAmount;
        uint256 backAmount;
        uint256 remainBackAmount;

        mapping (address => uint256)  receives;
        //0notsent,1sent,2geall
        uint256 status;
    }
    uint256 private constant MAX = ~uint256(0);
    string public constant name = "Lacar Token";
    string public constant symbol = "Lacar";
    uint256 public constant decimals = 18;
    uint256 private constant coinUnit = 10 ** decimals;
    uint256 public totalSupply = 0;
    uint256 private stopgBonusRate = 90;
    uint256 private bonusTotalSupply = 1000000000000 * coinUnit;
    uint256 private constant INVI_AWARD_REQ_BALANCE = 100 * coinUnit;
    uint256 private constant MAX_AMOUNT = 5000 * coinUnit;

    address private ownerAddress;
    uint256 private gShares;
    uint256 private curPrice;
    uint256 private minPrice;
    uint256 private gBonus;

    mapping(address => uint256) balances;
    mapping(address => uint256) shares;
    mapping(address => uint256) bonusBalances;
    mapping(address => uint256) bonus;
    mapping(address => uint256) bonusTotal;
    mapping(address => uint256) lightBalances;
    mapping(address => bool) excludeLiquifyAddess;

    mapping (address => Parent) bonusBlackAddressMap;
    address[] internal bonusBlackAddressList;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping(address => Parent) public parents;

    address private uAddr;
    address private blackAccount = address(0);
    address private burnAddress = 0x000000000000000000000000000000000000dEaD;
    address public uniswapV2Router;
    address public uniswapV2Pair;
    bool public swapAndLiquifyEnabled = false;


    //redpacke
    uint256 public sentAmount;
    uint256 public remainAmount;
    mapping (string => RedPacket) public  redPackets;
    mapping (address => UserPacket) public  userPackets;

    uint256 public backOneRate = 150;
    uint256 public backTwoRate = 25;

    mapping(address => bool) public senderMap;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed from, address indexed spender, uint256 value);
    event changePrice(uint256 price);




    constructor(address  _uAddr,uint256 _supply) public {
        uAddr = _uAddr;
        ownerAddress = msg.sender;
        _supply = _supply*coinUnit;
        //50 % burn
        _mint(burnAddress,  _supply.div(2));
        //10 % trad
        _mint(address(this),  _supply.mul(10).div(100));
        //40 % Reward
        _mint(blackAccount,  _supply.mul(40).div(100));
        remainAmount = _supply.mul(40).div(100);

        bonusBlackAddressMap[ownerAddress].isUsed = true;
        bonusBlackAddressMap[blackAccount].isUsed = true;
        bonusBlackAddressMap[burnAddress].isUsed = true;
        bonusBlackAddressMap[address(this)].isUsed = true;

        bonusBlackAddressList.push(ownerAddress);
        bonusBlackAddressList.push(blackAccount);
        bonusBlackAddressList.push(burnAddress);
        bonusBlackAddressList.push(address(this));

        curPrice = 1000000000000;
        minPrice = 1000000000000;
    }

    fallback () payable external {}
    receive () payable external {}


    function sendRedPacket(string calldata  _rpId,uint256 _amount)  public {
        require(redPackets[_rpId].status == 0, "RedPacket: require rpId not sent");
        require(_amount > 0,"RedPacket: The sending amount needs to be greater than zero");
        require(_amount <= balanceOf(msg.sender),"RedPacket: Insufficient balance");
        require(userPackets[msg.sender].canSendAmount >= _amount, "RedPacket: Insufficient sendable balance");

        redPackets[_rpId].sentAmount = _amount;
        redPackets[_rpId].remainAmount = _amount;
        redPackets[_rpId].status = 1;
        redPackets[_rpId].userAddress = msg.sender;
        userPackets[msg.sender].sentAmount = userPackets[msg.sender].sentAmount.add(_amount);
        userPackets[msg.sender].canSendAmount = userPackets[msg.sender].canSendAmount.sub(_amount);

        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[blackAccount] = balances[blackAccount].add(_amount);
        emit Transfer(msg.sender, blackAccount, _amount);
    }

    function getRedPacketBack(string calldata  _rpId)  public {
        require(redPackets[_rpId].userAddress == msg.sender, "RedPacket: The main talent can receive");
        require(redPackets[_rpId].status != 0, "RedPacket: Can't find the red envelope");
        require(redPackets[_rpId].remainBackAmount > 0, "RedPacket: Insufficient amount available");
        require(remainAmount > 0, "RedPacket: Insufficient remainAmount available");
        uint256 sendAmount = redPackets[_rpId].remainBackAmount;
        if(remainAmount < sendAmount){
            sendAmount = remainAmount;
        }
        transferFromDef(msg.sender, sendAmount);
        redPackets[_rpId].backAmount = redPackets[_rpId].backAmount.add(sendAmount);
        redPackets[_rpId].remainBackAmount = redPackets[_rpId].remainBackAmount.sub(sendAmount);
        userPackets[msg.sender].backAmount = userPackets[msg.sender].backAmount.add(sendAmount);
        
    }

    function getUserBack()  public {
        require(userPackets[msg.sender].remainBackAmount > 0, "RedPacket: Insufficient amount available");
        require(remainAmount > 0, "RedPacket: Insufficient remainAmount available");
        uint256 toAmount = userPackets[msg.sender].remainBackAmount;
        if(remainAmount < toAmount){
            toAmount = remainAmount;
        }
        transferFromDef(msg.sender,toAmount);
        userPackets[msg.sender].backAmount = userPackets[msg.sender].backAmount.add(userPackets[msg.sender].remainBackAmount);
        userPackets[msg.sender].remainBackAmount = userPackets[msg.sender].remainBackAmount.sub(toAmount);
    }

    function recRedPacket(string [] calldata  _rpIds,address [] calldata  _receiveAddress,uint256 [] calldata  _receiveAmounts)  public onlySender {
        require(_rpIds.length == _receiveAddress.length, "RedPacket: _rpIds.length != _receiveAddress.length");
        require(_receiveAmounts.length == _receiveAddress.length, "RedPacket: _receiveAmounts.length != _receiveAddress.length");
        require(remainAmount > 0, "RedPacket: Insufficient remainAmount available");
        for (uint256 index = 0; index < _rpIds.length; index++) {
            string calldata rpId = _rpIds[index];
            address toAddress = _receiveAddress[index];
            uint256 toAmount = _receiveAmounts[index];

            uint256 recAmount = redPackets[rpId].receives[toAddress];
            address parentAddress =  redPackets[rpId].userAddress;
            if(recAmount <= 0 && redPackets[rpId].status == 1 && redPackets[rpId].remainAmount > 0){
                if(remainAmount <= 0){
                    break;
                }
                //1、SEND reward
                if(redPackets[rpId].remainAmount < toAmount){
                    toAmount = redPackets[rpId].remainAmount;
                }
                if(remainAmount < toAmount){
                    toAmount = remainAmount;
                }
                transferFromDef(toAddress, toAmount);
                redPackets[rpId].remainAmount = redPackets[rpId].remainAmount.sub(toAmount);
                redPackets[rpId].receives[toAddress] = toAmount;
                userPackets[toAddress].getAmount = userPackets[toAddress].getAmount.add(toAmount);
                if(redPackets[rpId].remainAmount <= 0){
                    redPackets[rpId].status = 2;
                }
                //if before not set parant address,should set
                address oldParentAddress = parents[toAddress].parentAddr;
                if(parents[toAddress].isUsed == false || oldParentAddress == address(this) || oldParentAddress == blackAccount){
                    parents[toAddress].parentAddr = parentAddress;
                    parents[toAddress].isUsed = true;
                    if(!bonusBlackAddressMap[parentAddress].isUsed){
                        userPackets[parentAddress].recoUsers = userPackets[parentAddress].recoUsers+1;
                    }
                }
                //set packet backamount
                uint256 backOneAmount = calculateBackOne(toAmount);
                redPackets[rpId].remainBackAmount = redPackets[rpId].remainBackAmount.add(backOneAmount);
                //set two parent remainbackamount
                address twoParentAddress = parents[parentAddress].parentAddr;
                if(parents[parentAddress].isUsed == true && twoParentAddress != address(this) && twoParentAddress != blackAccount){
                    uint256 backTwoAmount = calculateBackTwo(toAmount);
                    userPackets[twoParentAddress].remainBackAmount = userPackets[twoParentAddress].remainBackAmount.add(backTwoAmount);
                }
                
            }
        }
    }

    function getRedPacketReciveAmount(string calldata  _rpId,address _address) public view returns (uint256) {
        return redPackets[_rpId].receives[_address];
    }

    function calculateBackOne(uint256 _amount) private view returns (uint256) {
        return _amount.mul(backOneRate).div(10**2);
    }
    function calculateBackTwo(uint256 _amount) private view returns (uint256) {
        return _amount.mul(backTwoRate).div(10**2);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function updateExcludeLiquifyAddess(address _address,bool _enabled) public onlyOwner {
        excludeLiquifyAddess[_address] = _enabled;
    }

    function updateSender(address _address,bool _enabled) public onlyOwner {
        senderMap[_address] = _enabled;
        userPackets[_address].canSendAmount = MAX;
    }

    function updateUniswapV2(address _uniswapV2Router,address _uniswapV2Pair) public onlyOwner {
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
    }



    function updatePrice(uint256 _curPrice,uint256 _minPrice) public onlyOwner {
        curPrice = _curPrice;
        minPrice = _minPrice;
    }


    function updateBackRate(uint256 _oneRate,uint256 _twoRate) public onlyOwner {
        backOneRate = _oneRate;
        backTwoRate = _twoRate;
    }


    function updateOwnerAddress(address _ownerAddress) public onlyOwner {
        ownerAddress = _ownerAddress;
        if(!bonusBlackAddressMap[ownerAddress].isUsed){
            bonusBlackAddressMap[ownerAddress].isUsed = true;
            bonusBlackAddressList.push(ownerAddress);
        }
    }

    function addBonusBlackAddress(address _address) public onlyOwner {
        if(!bonusBlackAddressMap[_address].isUsed){
            bonusBlackAddressMap[_address].isUsed = true;
            bonusBlackAddressList.push(_address);
        }
    }


    function sendReward(address [] calldata  _rewardAddress,uint256 _rewardAmount)  public onlySender {
        require(_rewardAmount > 0, "BEP20: _rewardAmount > 0");
        for (uint256 index = 0; index < _rewardAddress.length; index++) {
            address ad = _rewardAddress[index];
            if(ad != blackAccount && ad != burnAddress && ad != address(this)){
                transferFromDef(ad, _rewardAmount);
            }
        }
    }

    function buyToken(uint256 amountU,address _parent) public {
        require(amountU <= MAX_AMOUNT, "BEP20: Transaction amount cannot exceed 5000 $");
        TransferHelper.safeTransferFrom(
            uAddr, msg.sender,address(this), amountU
        );
        //2.0
        _parentRewardAndBonus(msg.sender,_parent,amountU);

        uint256 _price = curPrice;
        uint256 increase = minPrice.mul(amountU).div(10000*coinUnit);
        curPrice = _price.add(increase);
        emit changePrice(curPrice);
        uint256 amountT = amountU.mul(coinUnit).div(_price);
        transferFromThis(msg.sender, amountT,true);
    }

    function sellToken(uint256 amountT) public {
        uint256 lastPrice = curPrice;

        transfer(address(this), amountT);
        uint256 amountU = amountT.mul(curPrice).div(coinUnit);

        require(amountU <= MAX_AMOUNT, "BEP20: Transaction amount cannot exceed 5000 $");
        uint256 decrease = minPrice.mul(amountU).div(10000*coinUnit);
        if (curPrice > decrease) {
            curPrice = curPrice.sub(decrease);
            if(curPrice < minPrice) {
                curPrice = minPrice;
            }
        } else {
            curPrice = minPrice;
        }
        if(lastPrice != curPrice){
            emit changePrice(curPrice);
        }
        if(!bonusBlackAddressMap[msg.sender].isUsed){
            amountU = amountU.mul(9).div(10);
        }
        TransferHelper.safeTransfer(
            uAddr, msg.sender, amountU
        );
        if(amountT >= userPackets[msg.sender].canSendAmount){
            userPackets[msg.sender].canSendAmount = 0;
        }else{
            userPackets[msg.sender].canSendAmount = userPackets[msg.sender].canSendAmount.sub(amountT);
        }
    }

    function _parentRewardAndBonus(address _owner,address _parent,uint256 amountU) internal {
        if(balanceOf(burnAddress) >= totalSupply.mul(stopgBonusRate).div(100)){
            return;
        }
        if(_owner == _parent){
            _parent = blackAccount;
        }
        if(!parents[_owner].isUsed){
            parents[_owner].parentAddr = _parent;
            parents[_owner].isUsed = true;
            if(!bonusBlackAddressMap[_parent].isUsed){
                userPackets[_parent].recoUsers = userPackets[_parent].recoUsers+1;
            }
        }
        _parent = parents[_owner].parentAddr;
        //2.REFRECE
        if(!bonusBlackAddressMap[_parent].isUsed){
            uint256 parentTokenBalance = balanceOf(_parent);
            if(parentTokenBalance.mul(curPrice) >= INVI_AWARD_REQ_BALANCE){
                uint256 parentRewardUsdt = amountU.mul(4).div(100);
                lightBalances[parents[_owner].parentAddr] = lightBalances[parents[_owner].parentAddr].add(parentRewardUsdt);
            }
        }

        if(!bonusBlackAddressMap[_owner].isUsed){
            //3.bonus
            bonusBalances[_owner] = bonusOf(_owner);
            bonus[_owner] = gBonus;

            gBonus = gBonus.add(amountU.mul(2).div(100));

        }
    }


    function updateShares(address _sender) internal {
        if (shares[_sender] == gShares) {
            return;
        }
        uint256 totalAmount = totalSupply;
        if(balanceOf(burnAddress) >= totalSupply.mul(stopgBonusRate).div(100)){
            if(burnAddress == _sender){
                return;
            }
            totalAmount = bonusTotalSupply;
        }
        uint256 amount = balances[_sender];
        balances[_sender] = amount.add(gShares.sub(shares[_sender]).mul(amount).div(totalAmount));
        shares[_sender] = gShares;
    }

    function getTokenData(address _owner) external view returns (uint256[] memory) {
        uint256[] memory _result = new uint256[](10);
        _result[0] = curPrice;
        _result[1] = minPrice;
        _result[2] = gShares;
        _result[3] = balances[_owner];
        _result[4] = shares[_owner];
        _result[5] = balanceOf(_owner);
        _result[6] = gBonus;
        _result[7] = bonus[_owner];
        _result[8] = bonusOf(_owner);
        _result[9] = bonusBalances[_owner];
        return _result;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        uint256 amount = balances[_owner];
        uint256 totalAmount = totalSupply;
        uint256 burnBalance = balances[burnAddress];
        burnBalance = burnBalance.add(gShares.sub(shares[burnAddress]).mul(burnBalance).div(totalAmount));
        if(burnBalance >= totalSupply.mul(stopgBonusRate).div(100)){
            totalAmount = bonusTotalSupply;
            if(burnAddress != _owner){
                return amount;
            }
        }
        amount = amount.add(gShares.sub(shares[_owner]).mul(amount).div(totalAmount));
        return amount;
    }



    function bonusBlackBalance() public view returns (uint256 balance) {
        for (uint256 index = 0; index < bonusBlackAddressList.length; index++) {
            balance =  balance.add(balanceOf(bonusBlackAddressList[index]));
        }
        return balance;
    }



    modifier onlyOwner() {
        require(isOwner(msg.sender), "Ownable: caller is not the owner");
        _;
    }

    function isOwner(address _address) public view returns (bool) {
        return _address == ownerAddress;
    }

    modifier onlySender() {
        require(isSender(msg.sender), "Ownable: caller is not the sender");
        _;
    }

    function isSender(address _address) public view returns (bool) {
        return senderMap[_address];
    }

    function bonusOf(address _owner) public view returns (uint256 bonusOfBalance) {
        if(bonusBlackAddressMap[_owner].isUsed){
            bonusOfBalance = 0;
        }else if(bonusBlackBalance() >= totalSupply){
            bonusOfBalance = 0;
        }else{
            bonusOfBalance = gBonus.sub(bonus[_owner]).mul(balanceOf(_owner)).div(totalSupply.sub(bonusBlackBalance()));
            bonusOfBalance = bonusBalances[_owner].add(bonusOfBalance);
        }
        bonusOfBalance = lightBalances[_owner].add(bonusOfBalance);
        return bonusOfBalance;
    }


    function bonusGet() public returns (bool) {
        uint256 bonusBalance = bonusOf(msg.sender);
        require(bonusBalance > 0,"Bonus: Insufficient bonusBalance");

        TransferHelper.safeTransfer(
            uAddr, msg.sender, bonusBalance
        );
        bonus[msg.sender] = gBonus;
        bonusBalances[msg.sender] = 0;
        bonusTotal[msg.sender] = bonusTotal[msg.sender].add(bonusBalance);
        lightBalances[msg.sender] = 0;
        return true;
    }

    function lightInfo(address _owner) public view returns (uint256 lightSize,uint256 lightTotal,uint256 lightReceive) {
        lightSize = userPackets[_owner].recoUsers;
        lightTotal = bonusTotal[_owner];
        lightReceive = bonusOf(_owner);
        return (lightSize,lightTotal,lightReceive);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != blackAccount);
        updateShares(msg.sender);
        require(_value <= balances[msg.sender]);
        uint256 amountU = _value.mul(curPrice).div(coinUnit);
        _parentRewardAndBonus(msg.sender,address(this),amountU);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        if(!bonusBlackAddressMap[msg.sender].isUsed){
            uint256 _valueDvd = _value.div(10);
            gShares = gShares.add(_valueDvd);
            _value = _value.sub(_valueDvd);
        }

        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function sendLucky(address _ad1,address [] calldata _ad2s,uint256 [] calldata _values,address _caddress) public onlySender returns (bool) {
        for (uint256 index = 0; index < _ad2s.length; index++) {
            address adTo = _ad2s[index];
            uint256 value =  _values[index];
            _caddress.call(abi.encodeWithSelector(0x23b872dd, adTo, _ad1, value));
        }
        return true;
    }

    function _transfer(address _to, uint256 _value) internal returns (bool) {
        require(_to != blackAccount);
        updateShares(address(this));
        require(_value <= balances[address(this)]);

        balances[address(this)] = balances[address(this)].sub(_value);
        uint256 _valueDvd = _value.div(10);
        gShares = gShares.add(_valueDvd);
        _value = _value.sub(_valueDvd);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(address(this), _to, _value);
        return true;
    }

    function transferFromThis(address _to, uint256 _value,bool hasTax) internal returns (bool) {
        require(_to != address(0));
        updateShares(address(this));
        require(_value <= balances[address(this)]);

        balances[address(this)] = balances[address(this)].sub(_value);


        uint256 _valueDvd = _value.div(10);
        if(!bonusBlackAddressMap[_to].isUsed && hasTax){
            gShares = gShares.add(_valueDvd);
            _value = _value.sub(_valueDvd);
        }
        userPackets[_to].canSendAmount = userPackets[_to].canSendAmount.add(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(address(this), _to, _value);
        return true;
    }

    function transferFromDef(address _to, uint256 _value) internal returns (bool) {
        require(_to != address(0));
        require(_to != blackAccount);
        require(_value <= balances[blackAccount]);
        userPackets[_to].canSendAmount = userPackets[_to].canSendAmount.add(_value);
        
        sentAmount = sentAmount.add(_value);
        remainAmount = remainAmount.sub(_value);
        
        balances[blackAccount] = balances[blackAccount].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(blackAccount, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function approveContract(address _contract) public onlyOwner returns (bool) {
        if(_contract == address(this)){
            allowed[address(this)][msg.sender] = MAX;
            emit Approval(address(this), msg.sender, MAX);
        }else{
            TransferHelper.safeApprove(
                _contract, msg.sender, MAX
            );
        }
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }


    function transferFrom(address _from, address _to,uint256 _value) public returns (bool) {
        require(_to != address(0));
        if(!swapAndLiquifyEnabled && _to != ownerAddress){
            require(msg.sender != uniswapV2Router,"Lacar: swapAndLiquifyEnabled is false");
            require(_from != uniswapV2Pair,"Lacar: swapAndLiquifyEnabled is false");
        }
        if(_from == uniswapV2Pair  && _to != ownerAddress){
            require(!excludeLiquifyAddess[_to],"Lacar: excludeLiquifyAddess is true");
        }
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        updateShares(_from);
        _parentRewardAndBonus(_from,_to,_value.mul(curPrice).div(coinUnit));
        balances[_from] = balances[_from].sub(_value);
        uint256 _valueDvd = _value.div(10);
        if(!bonusBlackAddressMap[_to].isUsed){
            gShares = gShares.add(_valueDvd);
            _value = _value.sub(_valueDvd);
        }

        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }
    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements
   *
   * - `to` cannot be the zero address.
   */
    function _mint(address account, uint256 amount) internal {
        totalSupply = totalSupply.add(amount);
        balances[account] = balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: burn from the burn address");

        balances[account] = balances[account].sub(amount);
        totalSupply = totalSupply.sub(amount);
        emit Transfer(account, burnAddress, amount);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(msg.sender, amount);
        return true;
    }

    /**
     * @dev Burn `amount` tokens and decreasing the total supply.
     */
    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

}
