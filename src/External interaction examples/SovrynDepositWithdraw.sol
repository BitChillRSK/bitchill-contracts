//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface ILoanTokenLogicLM {
    // function mint(address receiver, uint256 depositAmount, bool useLM) external;
    function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount);
    function burn(address user, uint256 burnAmount) external returns (uint256 loanAmountPaid);
    function tokenPrice() external returns (uint256 price);
    function assetBalanceOf(address _owner) external view returns (uint256);
    function profitOf(address user) external view returns (int256);
}

contract SovrynDepositWithdraw {
    IERC20 docToken;
    IERC20 iSUSD;
    ILoanTokenLogicLM loanTokenProxy;

    constructor(address _docToken, address _loanTokenProxy) {
        // docToken: 0xcb46c0ddc60d18efeb0e586c17af6ea36452dae0
        // loanTokenProxy: 0x74e00A8CeDdC752074aad367785bFae7034ed89f
        docToken = IERC20(_docToken);
        iSUSD = IERC20(_loanTokenProxy);
        loanTokenProxy = ILoanTokenLogicLM(_loanTokenProxy);
    }

    function depositDoc(uint256 amount) external {
        docToken.transferFrom(msg.sender, address(this), amount);
        docToken.approve(address(loanTokenProxy), amount);
        loanTokenProxy.mint(address(this), amount);
        // loanTokenProxy.mint(address(this), amount, false);
        // iSUSD.transfer(msg.sender, iSUSD.balanceOf(address(this)));
    }

    function withdrawDoc(uint256 docAmount) external {
        // iSUSD.transferFrom(msg.sender, address(this), iSUSD.balanceOf(msg.sender));
        // loanTokenProxy.burn(msg.sender, iSUSD.balanceOf(address(this)));

        uint256 exchangeRate = loanTokenProxy.tokenPrice(); // esto devuelve la tasa de cambio
        uint256 iSusdToRepay = docAmount * 1e18 / exchangeRate;
        loanTokenProxy.burn(msg.sender, iSusdToRepay);
    }

    function getUnderlyingAmount() external view returns (uint256 underlyingAmount) {
        underlyingAmount =
            loanTokenProxy.assetBalanceOf(address(this)) + uint256(loanTokenProxy.profitOf(address(this)));
    }
}
