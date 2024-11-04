// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PRNT is ERC20 {
constructor () ERC20('PRNToken','PRNT') {}
function mint(address _owner,uint _value) public {
    _mint(_owner, _value);
}
}