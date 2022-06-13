%lang starknet

from onlydust.deathnote.core.badge_registry.library import UserInformation

@contract_interface
namespace IBadgeRegistry:
    func set_badge_contract(badge_contract : felt):
    end

    func grant_admin_role(address : felt):
    end

    func revoke_admin_role(address : felt):
    end

    func grant_register_role(address : felt):
    end

    func revoke_register_role(address : felt):
    end

    func register_github_handle(user_address : felt, handle : felt):
    end

    func unregister_github_handle(user_address : felt, handle : felt):
    end

    func badge_contract() -> (badge_contract : felt):
    end

    func get_user_information(user_address : felt) -> (user : UserInformation):
    end

    func get_user_information_from_github_handle(handle : felt) -> (user : UserInformation):
    end
end
