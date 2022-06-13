%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_not_zero

from onlydust.deathnote.interfaces.badge import IBadge

from openzeppelin.access.ownable import Ownable

#
# Structs
#
struct Handles:
    member github : felt
end

struct UserInformation:
    member badge_contract : felt
    member token_id : Uint256
    member handles : Handles
end

#
# Events
#
@event
func GithubHandleRegistered(badge_contract : felt, token_id : Uint256, handle : felt):
end

@event
func GithubHandleUnregistered(badge_contract : felt, token_id : Uint256, handle : felt):
end

#
# Storage
#
@storage_var
func badge_contract_() -> (address : felt):
end

@storage_var
func users_(address : felt) -> (user : UserInformation):
end

@storage_var
func github_handles_to_user_address_(handle : felt) -> (user_address : felt):
end

namespace badge_registry:
    func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt
    ):
        Ownable.initializer(owner)
        return ()
    end

    func set_badge_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        badge_contract : felt
    ):
        Ownable.assert_only_owner()
        badge_contract_.write(badge_contract)
        return ()
    end

    func owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        owner : felt
    ):
        return Ownable.owner()
    end

    func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_owner : felt
    ):
        Ownable.transfer_ownership(new_owner)
        return ()
    end

    func badge_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        badge_contract : felt
    ):
        let (badge_contract) = badge_contract_.read()
        return (badge_contract)
    end

    func get_user_information{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_address : felt
    ) -> (user : UserInformation):
        let (user) = users_.read(user_address)

        with_attr error_message("Badge Registry: Unregistered user"):
            assert_not_zero(user.badge_contract)
        end

        return (user)
    end

    func get_user_information_from_github_handle{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(handle : felt) -> (user : UserInformation):
        let (user_address) = github_handles_to_user_address_.read(handle)
        let (user) = get_user_information(user_address)
        return (user)
    end

    func register_github_handle{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_address : felt, handle : felt
    ):
        Ownable.assert_only_owner()

        with_attr error_message("Badge Registry: Github handle already registered"):
            let (address) = github_handles_to_user_address_.read(handle)
            assert 0 = address
        end

        let (user) = users_.read(user_address)
        with user:
            internal.mint_badge_if_needed(user_address)
            internal.set_github_handle(handle)
        end

        users_.write(user_address, user)
        github_handles_to_user_address_.write(handle, user_address)

        return ()
    end

    func unregister_github_handle{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
    }(user_address : felt, handle : felt):
        Ownable.assert_only_owner()
        let (user) = users_.read(user_address)
        with_attr error_message(
                "Badge Registry: The address does not match the github handle provided"):
            assert handle = user.handles.github
        end
        with user:
            internal.remove_github_handle()
        end

        users_.write(user_address, user)
        github_handles_to_user_address_.write(handle, 0)

        return ()
    end
end

namespace internal:
    func mint_badge_if_needed{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, user : UserInformation
    }(address : felt):
        let (badge_contract) = badge_contract_.read()
        with_attr error_message("Badge Registry: Missing Badge contract"):
            assert_not_zero(badge_contract)
        end

        if badge_contract == user.badge_contract:
            return ()  # user badge contract is up-to-date, no need to mint
        end

        # Update user with minted token
        let (token_id) = IBadge.mint(badge_contract, address)
        let user = UserInformation(
            badge_contract=badge_contract, token_id=token_id, handles=user.handles
        )

        return ()
    end

    func set_github_handle{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, user : UserInformation
    }(handle : felt):
        GithubHandleRegistered.emit(user.badge_contract, user.token_id, handle)

        let user = UserInformation(
            badge_contract=user.badge_contract,
            token_id=user.token_id,
            handles=Handles(github=handle),
        )
        return ()
    end

    func remove_github_handle{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, user : UserInformation
    }():
        GithubHandleUnregistered.emit(user.badge_contract, user.token_id, user.handles.github)

        let user = UserInformation(
            badge_contract=user.badge_contract, token_id=user.token_id, handles=Handles(github=0)
        )
        return ()
    end
end
