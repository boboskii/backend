//SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

//https://github.com/alchemyplatform/NFT-Marketplace-Tutorial/blob/master/contracts/NFTMarketplace.sol
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//1.荷兰拍卖
//2.立即购买
//3.托管TBA
//4.版税
//5.fisrt mint



contract NFTMarketplace is IERC20  {
    //https://docs.moonbeam.network/cn/builders/interoperability/xcm/xc20/overview/
    // moonbeam xcdot: 0xffffffff1fcacbd218edc0eba20fc2308c778080
    IERC20 public constant token=IERC20(0xffffffff1fcacbd218edc0eba20fc2308c778080);

     bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;.
     bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);

    //The structure to store info about a listed token
        
        uint256 private constant feesPercentage=30;
        uint256 private constant PercentageDenominator=10000;
 
        uint256 private fees;
        uint256 itemsCount;
        mapping(uint256 => bytes32[]) public itemInfo; // // 160 bits _creator address + 64 bits price+ isapproved islocked  istba Royalties 
        mapping(address => uint64[]) public allList; //user all listed NFT
        mapping(address => uint64[]) public contact; //user all listed NFT

    //the event emitted when a token is successfully listed
    event Listed(    
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        uint _price,
        address indexed _owner,
        address indexed _creator
    );

    event UnListed(    
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        address indexed _owner
    );

    event Buyed(
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        uint _price,
        address indexed _buyer
    );

    event ChangePrice(
        uint _itemId,
        address indexed _nft,
        uint _tokenId,
        uint _newPrice
    );

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == ERC4906_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    function getPrice(_itemId) public view returns (uint256) {
    return listingPrice;
    }   

    function updatePrice() public view returns (uint256) {

    } 

    function getAllList() public view returns (uint256) {

    }


    function listItem(address _nft, uint256 _tokenId, uint256 _price)
        external
        returns(uint256)
    {
        require(_nft != address(0), "Zero address!");
        require(_tokenId > 0, "Be greater than zero!");
        require(
            IERC721(_nft).ownerOf(_tokenId) == msg.sender, 
            "Only owner can list!"
        );
        
        // increment itemCount

        itemsCount++;
        uint256 itemId = itemsCount;
        uint256 _creatorRoyalties = 0;

        getRoyalties(_nft) ; //需要改写
        
        // add new item to items mapping
        bytes32 Info1=bytes32(uint256(_nft)<<96
        
        uint256(_price)<<128+uint256(_creatorRoyalties)<<64);


      itemInfo=
      allList[msg.sender].push(uint64(itemId));
        // emit Offered event
        emit LogCreateItem(
            itemId,
            _nft,
            _tokenId,
            _price,
            msg.sender,
            _creator
        );

        // transfer nft
        IERC721(_nft).safeTransferFrom(msg.sender, address(this), _tokenId);

        return itemsCount;
    }

    function checkRoyalties(address _contract) 
        internal 
        view
        returns (bool) 
    {
        (bool success) = IERC165(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    function getRoyalties(address _contract) 
        internal 
    {
     if(checkRoyalties(_nft)){
            (_creator, _creatorRoyalties) = IERC2981(_nft).royaltyInfo(_tokenId, _price);
            require(_creator != address(0), "Creator is zero address!");
        }
        else
            _creator = msg.sender;
    }

    function _isApprovedForAll(address TokenAddress, address owner) private view returns (bool) {
        IERC1155 token = IERC1155(TokenAddress);
        return token.isApprovedForAll(owner, address(this));
    }

       function buyAssets(address TokenAddress, uint256 tokenId, uint256 quantity)
        external
        payable
        isListed(TokenAddress, tokenId)
    {
        Listing storage listing = s_listings[msg.sender][tokenId];
        if (quantity <= 0 || quantity > listing.quantity) revert();
        uint256 totalPrice = listing.price * quantity;
        require(msg.value == totalPrice, "Not enough funds sent");

        s_proceeds[listing.seller] += totalPrice;
        if (quantity == listing.quantity) {
            delete s_listings[msg.sender][tokenId];
        } else {
            listing.quantity -= quantity;
        }
        IERC1155 token = IERC1155(TokenAddress);
        token.safeTransferFrom(address(this), msg.sender, tokenId, quantity, "");
        emit assetBought(TokenAddress, tokenId, quantity, totalPrice, msg.sender, listing.seller);
    }

        function getListingDetails(address tokenAddress, uint256 tokenId)
        external
        view
        returns (uint256 price, address seller, uint256 quantity)
    {
        Listing storage listing = s_listings[tokenAddress][tokenId];
        require(listing.seller != address(0), "Listing not found");
        return (listing.price, listing.seller, listing.quantity);
    }


   function purchase(address _nftAddr, uint256 _tokenId) payable public {
        Order storage _order = nftList[_nftAddr][_tokenId]; // 取得Order        
        require(_order.price > 0, "Invalid Price"); // NFT价格大于0
        require(msg.value >= _order.price, "Increase price"); // 购买价格大于标价
        // 声明IERC721接口合约变量
        IERC721 _nft = IERC721(_nftAddr);
        require(_nft.ownerOf(_tokenId) == address(this), "Invalid Order"); // NFT在合约中

        // 将NFT转给买家
        _nft.safeTransferFrom(address(this), msg.sender, _tokenId);
    
    require(amount > 0, "You need to sell at least some tokens");
    uint256 allowance = token.allowance(msg.sender, address(this));
    require(allowance >= amount, "Check the token allowance");
    token.transferFrom(msg.sender, address(this), amount);
    payable(msg.sender).transfer(amount);
    emit Sold(amount);



        delete nftList[_nftAddr][_tokenId]; // 删除order

        // 释放Purchase事件
        emit Purchase(msg.sender, _nftAddr, _tokenId, msg.value);
    }

    function getLatest() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getById() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getByUser() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function getByToken() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }

    function checkIsAproved() public view returns (ListedToken memory) {
        uint256 currentTokenId = _tokenIds.current();
        return idToListedToken[currentTokenId];
    }



}