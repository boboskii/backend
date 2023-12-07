// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

// fork and modified from https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol
// fork and modified from https://github.com/scaffold-eth/scaffold-eth/blob/composable-svg-nft/packages/hardhat/contracts/Loogies.sol

import "../library/chirulabs/ERC721A.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import 'base64-sol/base64.sol';
import "hardhat/console.sol";
import './HexStrings.sol';
import './ToColor.sol';



contract Charter is ERC721A{


  using Strings for uint256;
  using HexStrings for uint160;
  using ToColor for bytes3;
  using Counters for Counters.Counter;
  mapping (uint256 => bytes3) public color;
  mapping (uint256 => uint256) public chubbiness;
  mapping(uint256 => bytes32) public genes;

  uint256 mintDeadline = block.timestamp + 24 hours;

  Counters.Counter private _tokenIds;

        constructor(
        ) ERC721A("Charter", "CHARTER") {
        }




  function mintItem() public returns (uint256) {
      require(block.timestamp < mintDeadline, "DONE MINTING");
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(msg.sender, id);

      genes[id] = keccak256(abi.encodePacked( blockhash(block.number-1), msg.sender, address(this) ));
      color[id] = bytes2(genes[id][0]) | ( bytes2(genes[id][1]) >> 8 ) | ( bytes3(genes[id][2]) >> 16 );
      chubbiness[id] = 35+((55*uint256(uint8(genes[id][3])))/255);

      return id;
  }

  function tokenURI(uint256 id) public view override returns (string memory) {
      require(_exists(id), "not exist");
      string memory name = string(abi.encodePacked('Loogie #',id.toString()));
      string memory description = string(abi.encodePacked('This Loogie is the color #',color[id].toColor(),' with a chubbiness of ',uint2str(chubbiness[id]),'!!!'));
      string memory image = Base64.encode(bytes(generateSVGofTokenById(id)));

      return
          string(
              abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                          abi.encodePacked(
                              '{"name":"',
                              name,
                              '", "description":"',
                              description,
                              '", "external_url":"https://burnyboys.com/token/',
                              id.toString(),
                              '", "attributes": [{"trait_type": "color", "value": "#',
                              color[id].toColor(),
                              '"},{"trait_type": "chubbiness", "value": ',
                              uint2str(chubbiness[id]),
                              '}], "owner":"',
                              (uint160(ownerOf(id))).toHexString(20),
                              '", "image": "',
                              'data:image/svg+xml;base64,',
                              image,
                              '"}'
                          )
                        )
                    )
              )
          );
  }

  function generateSVGofTokenById(uint256 id) internal view returns (string memory) {

    string memory svg = string(abi.encodePacked(
      '<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">',
        renderTokenById(id),
      '</svg>'
    ));

    return svg;
  }

  // Visibility is `public` to enable it being called by other contracts for composition.
  function renderTokenById(uint256 id) public view returns (string memory) {
    string memory render = string(abi.encodePacked(
      '<g id="eye1">',
          '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_1" cy="154.5" cx="181.5" stroke="#000" fill="#fff"/>',
          '<ellipse ry="3.5" rx="2.5" id="svg_3" cy="154.5" cx="173.5" stroke-width="3" stroke="#000" fill="#000000"/>',
        '</g>',
        '<g id="head">',
          '<ellipse fill="#',
          color[id].toColor(),
          '" stroke-width="3" cx="204.5" cy="211.80065" id="svg_5" rx="',
          chubbiness[id].toString(),
          '" ry="51.80065" stroke="#000"/>',
        '</g>',
        '<g id="eye2">',
          '<ellipse stroke-width="3" ry="29.5" rx="29.5" id="svg_2" cy="168.5" cx="209.5" stroke="#000" fill="#fff"/>',
          '<ellipse ry="3.5" rx="3" id="svg_4" cy="169.5" cx="208" stroke-width="3" fill="#000000" stroke="#000"/>',
        '</g>'
      ));

    return render;
  }


    function tokenURI(uint256 tokenId) override public pure returns (string memory) {
        string[3] memory parts;

        parts[0] = "<svg xmlns='http://www.w3.org/2000/svg' preserveAspectRatio='xMinYMin meet' viewBox='0 0 350 350'><style>.base { fill: white; font-family: serif; font-size: 300px; }</style><rect width='100%' height='100%' fill='brown' /><text x='100' y='260' class='base'>";

        parts[1] = Strings.toString(tokenId);

        parts[2] = "</text></svg>";

        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            "{\"name\":\"Badge #", 
            Strings.toString(tokenId), 
            "\",\"description\":\"Badge NFT with on-chain SVG image.\",",
            "\"image\": \"data:image/svg+xml;base64,", 
            // Base64.encode(bytes(output)), 
            Base64.encode(bytes(abi.encodePacked(parts[0], parts[1], parts[2]))),     
            "\"}"
            ))));

        return string(abi.encodePacked("data:application/json;base64,", json));
    }    
}


}
  