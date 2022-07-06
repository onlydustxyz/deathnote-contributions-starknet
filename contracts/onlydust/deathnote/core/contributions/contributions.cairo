%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin

from onlydust.deathnote.core.contributions.library import contributions, Contribution

#
# Constructor
#
@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(admin : felt):
    return contributions.initialize(admin)
end

#
# Views
#
@view
func contribution{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    contribution_id : felt
) -> (contribution : Contribution):
    return contributions.contribution(contribution_id)
end

@view
func all_contributions{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    contributions_len : felt, contributions : Contribution*
):
    return contributions.all_contributions()
end

@view
func all_open_contributions{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (contributions_len : felt, contributions : Contribution*):
    return contributions.all_open_contributions()
end

#
# Externals
#

@external
func grant_admin_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
):
    return contributions.grant_admin_role(address)
end

@external
func revoke_admin_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
):
    return contributions.revoke_admin_role(address)
end

@external
func grant_feeder_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
):
    return contributions.grant_feeder_role(address)
end

@external
func revoke_feeder_role{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
):
    return contributions.revoke_feeder_role(address)
end

@external
func new_contribution{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    contribution : Contribution
):
    return contributions.new_contribution(contribution)
end

@external
func assign_contributor_to_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(contribution_id : felt, contributor_id : Uint256):
    return contributions.assign_contributor_to_contribution(contribution_id, contributor_id)
end

@external
func unassign_contributor_from_contribution{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(contribution_id : felt):
    return contributions.unassign_contributor_from_contribution(contribution_id)
end

@external
func validate_contribution{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    contribution_id : felt
):
    return contributions.validate_contribution(contribution_id)
end
