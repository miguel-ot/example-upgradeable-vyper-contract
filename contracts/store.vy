# @version 0.3.7

implementation: public(address)
owner: public(address)
amount: public(uint256)

@external
def upgrade(addr: address):
    assert msg.sender == self.owner, "You are not the owner."
    self.implementation = addr

@external
def sum(a: uint256):
    self.amount += a

