// SPDX-License-Identifier: MIT
pragma solidity >=0.8.27;
import {Modifiers} from "../shared/Modifiers.sol";
import {Errors} from "../shared/Errors.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {ReentrancyGuard} from "../shared/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "hardhat/console.sol";

contract ERC721Facet is Modifiers, ERC721Holder, Errors, ReentrancyGuard {
    event MetadataUpdate(uint256 _tokenId);
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    using Strings for uint256;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);

    mapping(uint256 tokenId => string) private _tokenURIs;

      /// @notice Checks if the token exists and returns the owner's address
    /// @param tokenId The ID of the token to check
    /// @return address The address of the token owner
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = ownerOf(tokenId);
        require(owner!=address(0),ERC721NonexistentToken());
        return owner;
    }

    /// @notice Returns the base URI for token metadata
    /// @return string The base URI as a string
     function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

     /// @notice Retrieves the URI for the given token ID
    /// @param tokenId The ID of the token
    /// @return string The token URI
    function tokenURI(uint256 tokenId) public view virtual  returns (string memory) {
        _requireOwned(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via string.concat).
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }

        return tokenURI(tokenId);
    }

     /// @notice Sets the token URI for a given token ID
    /// @param tokenId The ID of the token
    /// @param _tokenURI The URI to assign to the token
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdate(tokenId);
    }



    /// @notice Gets the balance of tokens for a given address
    /// @param owner The address to query
    /// @return uint256 The number of tokens owned by the address
    function balanceOf(address owner) public view  returns (uint256) {
        require(owner != address(0), InvalidTokenOwner());
        return _balances[owner];
    }



    /// @notice Removes an element from an array by key and returns the new array
    /// @param arr The array to remove from
    /// @param key The value to remove
    /// @return uint256[] The updated array without the specified key
  function removeKey(uint256[] memory arr, uint key) internal pure returns (uint[] memory) {
    uint length = arr.length;
    
    for (uint i = 0; i < length; i++) {
        if (arr[i] == key) {
            arr[i] = arr[length - 1];  
            length--; 
            break;
        }
    }
    uint[] memory newArr = new uint[](length);
    
    for (uint j = 0; j < length; j++) {
        newArr[j] = arr[j];
    }

    return newArr;
    }

    /// @notice Gets the owner of a token
    /// @param tokenId The ID of the token
    /// @return address The address of the token owner
    function ownerOf(uint256 tokenId) public view  returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), InvalidTokenId());
        return owner;
    }

     /// @notice Approves another address to transfer a specific token
    /// @param to The address to be approved
    /// @param tokenId The ID of the token
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, InvalidTo());
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), NotApproved());

        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /// @notice Gets the approved address for a token
    /// @param tokenId The ID of the token
    /// @return address The approved address for the token
    function getApproved(uint256 tokenId) public view  returns (address) {
        require(_owners[tokenId] != address(0),ERC721NonexistentToken());
        return _tokenApprovals[tokenId];
    }


    /// @notice Sets or removes an operator for the caller
    /// @param operator The address to set approval for
    /// @param approved True to approve the operator, false to remove approval
    function setApprovalForAll(address operator, bool approved) public  {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }


    /// @notice Checks if an operator is approved for a given owner
    /// @param owner The owner of the tokens
    /// @param operator The operator to check
    /// @return bool True if the operator is approved, false otherwise
    function isApprovedForAll(address owner, address operator) public view  returns (bool) {
        return _operatorApprovals[owner][operator];
    }



    /// @notice Transfers a token from one address to another
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token
    function transferFrom(address from, address to, uint256 tokenId) public  {
        require(_isApprovedOrOwner(msg.sender, tokenId), NotApproved());
        _transfer(from, to, tokenId);
    }


    /// @notice Internal function to transfer token ownership
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token
    function _transfer(address from, address to, uint256 tokenId) internal   {
        require(ownerOf(tokenId) == from, InvalidFrom());
        require(to != address(0), InvalidTo());

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /// @notice Internal function to approve a specific address to transfer a token
    /// @param to The address to be approved
    /// @param tokenId The ID of the token
    function _approve(address to, uint256 tokenId) internal  {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /// @notice Checks if a spender is approved or owns a token
    /// @param spender The address spending or transferring the token
    /// @param tokenId The ID of the token
    /// @return bool True if approved or owner, false otherwise
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

     /// @notice Hook that is called before any token transfer
    /// @param from The address sending the token
    /// @param to The address receiving the token
    /// @param tokenId The ID of the token
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual  {}

    /// @notice Mints a new token and assigns it to an address
    /// @param to The address that will own the minted token
    /// @param tokenId The ID of the token to mint
    /// @param uri The URI for the token metadata
    function mint(address to, uint256 tokenId, string memory uri) public {
        require(to != address(0), InvalidTo());
        require(_owners[tokenId] == address(0), AlreadyMinted());

        _balances[to] += 1;
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = uri;
        emit Transfer(address(0), to, tokenId);
    }

    /// @notice Burns a token, removing it from circulation
    /// @param tokenId The ID of the token to burn
    function burn(uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(_isApprovedOrOwner(msg.sender, tokenId), NotApproved());

        _beforeTokenTransfer(owner, address(0), tokenId);

        _approve(address(0), tokenId);

        _balances[owner] -= 1;

        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }
}
