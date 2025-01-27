use garaga::definitions::Zero;
use garaga::ec_ops::G1PointTrait;
use garaga::definitions::SECP256K1;
use garaga::ec_ops::{DerivePointFromXHint, G1Point, MSMHint, msm_g1, u384};
use garaga::basic_field_ops::neg_mod_p;
use core::circuit::{CircuitModulus, u96};

pub const SECP256K1_G1_GENERATOR: G1Point = G1Point {
    x: u384 {
        limb0: 0x2dce28d959f2815b16f81798,
        limb1: 0x55a06295ce870b07029bfcdb,
        limb2: 0x79be667ef9dcbbac,
        limb3: 0x0,
    },
    y: u384 {
        limb0: 0xa68554199c47d08ffb10d4b8,
        limb1: 0x5da4fbfc0e1108a8fd17b448,
        limb2: 0x483ada7726a3c465,
        limb3: 0x0,
    },
};
pub const SECP256K1_N: [u96; 4] = [
    0xaf48a03bbfd25e8cd0364141, 0xfffffffffffffffebaaedce6, 0xffffffffffffffff, 0,
];

#[derive(Drop, Serde)]
struct Arguments {
    r: u256,
    s: u256,
    e: u256, // Hash challenge, not computed in this benchmark to exclude sha2 from the measurements
    pk_point: G1Point,
    msm_hint: MSMHint,
    msm_derive_hint: DerivePointFromXHint,
}

#[executable]
pub fn main(args: Array<felt252>) {
    println!("Verifying signature...");

    let mut arguments = args.span();
    let Arguments {
        r, s, e, pk_point, msm_hint, msm_derive_hint,
    } = Serde::deserialize(ref arguments).expect('failed to deserialize');

    assert(r < SECP256K1.n, '');
    assert(r != 0, '');

    assert(s < SECP256K1.n, '');
    assert(s != 0, '');

    assert(e < SECP256K1.n, '');
    assert(e != 0, '');

    pk_point.assert_on_curve(2);

    let modulus = TryInto::<[u96; 4], CircuitModulus>::try_into(SECP256K1_N).unwrap();
    let e_neg: u256 = neg_mod_p(e.into(), modulus).try_into().unwrap();
    let r: u384 = r.into();

    let points = array![SECP256K1_G1_GENERATOR, pk_point].span();
    let scalars = array![s, e_neg].span();

    let res = msm_g1(Option::None, msm_hint, msm_derive_hint, points, scalars, 2);
    assert(res.x.is_non_zero(), 'R.x == 0');
    assert(res.y.is_non_zero(), 'R.y == 0');
    // TODO: check res.y % 2 == 0
    assert(res.x == r, 'signature is invalid');
}
