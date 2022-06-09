%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IBadge:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func mint(to : felt) -> (tokenId : Uint256):
    end

    func ownerOf(tokenId : Uint256) -> (owner : felt):
    end

    func grant_admin_role(address : felt):
    end

    func revoke_admin_role(address : felt):
    end

    func grant_minter_role(address : felt):
    end

    func revoke_minter_role(address : felt):
    end

    func register_metadata_contract(label : felt, metadata_contract : felt):
    end

    func metadata_contract(label : felt) -> (metadata_contract : felt):
    end
end
