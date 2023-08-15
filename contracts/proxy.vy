# @version 0.3.7

implementation: public(address)
owner: public(address)
amount: public(uint256)

@external
def __init__(
    implementation_address: address
    ):
    self.implementation = implementation_address
    self.owner = msg.sender

@external
@payable
def __default__():
    raw_call(
        self.implementation,
        msg.data,
        max_outsize = 0,
        value = msg.value,
        is_delegate_call = True,
        revert_on_failure = True
    )
