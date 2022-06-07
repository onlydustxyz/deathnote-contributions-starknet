%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

from openzeppelin.token.erc721.library import (
    ERC721_initializer,
    ERC721_name,
    ERC721_symbol,
    ERC721_mint,
    ERC721_ownerOf,
)

from onlydust.deathnote.library.accesscontrol import AccessControl  # TODO change to OZ implem when 0.2.0 is released

from openzeppelin.security.safemath import SafeUint256

#
# Enums
#
struct Role:
    # Keep ADMIN role first of this list as 0 is the default admin value to manage roles in AccessControl library
    member ADMIN : felt  # ADMIN role, can assign/revoke roles
    member MINTER : felt  # MINTER role, can mint a token
end

#
# STORAGE
#
@storage_var
func total_supply_() -> (total_supply : Uint256):
end

namespace badge:
    # Initialize the badge name and symbol
    func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        admin : felt
    ):
        ERC721_initializer('Death Note Badge', 'DNB')
        AccessControl.constructor()
        AccessControl._grant_role(Role.ADMIN, admin)
        return ()
    end

    # Grant the ADMIN role to a given address
    func grant_admin_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ):
        AccessControl.grant_role(Role.ADMIN, address)
        return ()
    end

    # Revoke the ADMIN role from a given address
    func revoke_admin_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ):
        with_attr error_message("Badge: Cannot self renounce to ADMIN role"):
            internal.assert_not_caller(address)
        end
        AccessControl.revoke_role(Role.ADMIN, address)
        return ()
    end

    # Grant the MINTER role to a given address
    func grant_minter_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ):
        AccessControl.grant_role(Role.MINTER, address)
        return ()
    end

    # Revoke the MINTER role from a given address
    func revoke_minter_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt
    ):
        AccessControl.revoke_role(Role.MINTER, address)
        return ()
    end

    # Get the badge name
    func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
        return ERC721_name()
    end

    # Get the badge symbol
    func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        symbol : felt
    ):
        return ERC721_symbol()
    end

    # Mint a new token
    func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(to : felt) -> (
        tokenId : Uint256
    ):
        alloc_locals

        internal.assert_only_minter()

        let (local tokenId : Uint256) = total_supply_.read()
        ERC721_mint(to, tokenId)

        let (new_supply) = SafeUint256.add(tokenId, Uint256(1, 0))
        total_supply_.write(new_supply)

        return (tokenId)
    end

    # Get the owner of a tokenId
    func ownerOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenId : Uint256
    ) -> (owner : felt):
        return ERC721_ownerOf(tokenId)
    end
end

namespace internal:
    func assert_not_caller{syscall_ptr : felt*}(address : felt):
        let (caller_address) = get_caller_address()
        assert_not_zero(caller_address - address)
        return ()
    end

    func assert_only_minter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
        with_attr error_message("Badge: MINTER role required"):
            AccessControl._only_role(Role.MINTER)
        end

        return ()
    end
end
