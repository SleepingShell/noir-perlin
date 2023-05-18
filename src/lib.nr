use dep::std;
use dep::signed::Signed;

struct Coords {
    x: Signed,
    y: Signed,
}

impl Coords {
    fn diff(self, other: Self) -> Self {
        Self {
            x: self.x.sub(other.x).abs(),
            y: self.y.sub(other.y).abs(),
        }
    }
}

global DENOMINATOR = 1125899906842624; //2^50
global PERLIN_MAX = 64;
global pow123: u124 = 10633823966279326983230456482242756608; //2^123

// Return a psuedorandom integer in [0, 15]
fn random(x: u124, y: u124, scale: u124, seed: Field) -> u4 {
    let t = std::hash::mimc_bn254([x as Field, y as Field, scale as Field, seed]);

    let bits = t.to_le_bits(32);
    8*(bits[3] as u4) + 4*(bits[2] as u4) + 2*(bits[1] as u4) + (bits[0] as u4)
}

fn random_gradient_at(point: Coords, scale: u124, seed: Field) -> (Signed, Signed) {
    let DIRECTIONS: [(Signed, Signed); 16] = [
        (Signed { x: 1000, is_neg: false }, Signed { x: 0, is_neg: false }),
        (Signed { x: 923, is_neg: false }, Signed { x: 382, is_neg: false }),
        (Signed { x: 707, is_neg: false }, Signed { x: 707, is_neg: false }),
        (Signed { x: 382, is_neg: false }, Signed { x: 923, is_neg: false }),
        (Signed { x: 0, is_neg: false }, Signed { x: 1000, is_neg: false }),
        (Signed { x: 383, is_neg: true }, Signed { x: 923, is_neg: false }),
        (Signed { x: 708, is_neg: true }, Signed {x: 707, is_neg: false }),
        (Signed { x: 924, is_neg: true }, Signed { x: 382, is_neg: false}),
        (Signed { x: 1000, is_neg: true }, Signed { x: 0, is_neg: false }),
        (Signed { x: 924, is_neg: true }, Signed { x: 383, is_neg: true }),
        (Signed { x: 708, is_neg: true }, Signed { x: 708, is_neg: true }),
        (Signed { x: 383, is_neg: true }, Signed { x: 924, is_neg: true }),
        (Signed { x: 1, is_neg: true }, Signed { x: 1000, is_neg: true }),
        (Signed { x: 382, is_neg: false }, Signed { x: 924, is_neg: true }),
        (Signed { x: 707, is_neg: false }, Signed { x: 708, is_neg: true }),
        (Signed { x: 923, is_neg: false }, Signed { x: 383, is_neg: true }),
    ];
    
    // If this isn't done, the points reflected across the axes will have the same randomness
    let mut x = point.x.absi();
    let mut y = point.y.absi();
    if (point.x.is_neg) {
        x += pow123;
    }
    if (point.y.is_neg) {
        y += pow123;
    }

    let rand = random(x,y,scale,seed);

    let mut direction = (Signed::zero(), Signed::zero());
    for i in 0..16 {
        if (i as u4 == rand) {
            direction = DIRECTIONS[i];
        }
    };

    (direction.0.mul(point.x), direction.1.mul(point.y))
}

fn get_weight(corner: Coords, point: Coords, scale: u124) -> u124 {
    let diff = corner.diff(point);
    let res = (scale - diff.x.absi()) * (scale - diff.y.absi());

    res
}

fn get_corners(point: Coords, scale: u124) -> [Coords; 4] {
    let scaleS = Signed::toSigned(scale);

    let bottom_left = Coords {
        x: point.x.div(scaleS).mul(scaleS),
        y: point.y.div(scaleS).mul(scaleS),
    };

    [
        Coords { x: bottom_left.x, y: bottom_left.y },                          // BL
        Coords { x: bottom_left.x.add(scaleS), y: bottom_left.y },               // BR
        Coords { x: bottom_left.x, y: bottom_left.y.add(scaleS) },               // TL
        Coords { x: bottom_left.x.add(scaleS), y: bottom_left.y.add(scaleS) },    // TR
    ]
}

fn single_scale_perlin(point: Coords, scale: u124, seed: Field) -> Signed {
    let corners = get_corners(point, scale);

    let mut numerator = Signed::toSigned(0);
    for i in 0..4 {
        let corner = corners[i];
        let offsetx = point.x.sub(corner.x);
        let offsety = point.y.sub(corner.y);
        let offset = Coords {
            x: offsetx,
            y: offsety,
        };
        
        let gradient = random_gradient_at(corner, scale, seed);
        let dotx = gradient.0.mul(offset.x);
        let doty = gradient.1.mul(offset.y);
        let dot = dotx.add(doty);
        let weight = get_weight(corner, point, scale);

        let t = dot.muli(weight);
        numerator = numerator.add(t);
    }

    numerator.div(Signed::toSigned(scale * scale * scale))
}

fn compute_perlin(point: Coords, scale: u124, seed: Field) -> u124 {
    let mut perlin = Signed::toSigned(0);

    perlin = perlin.add(single_scale_perlin(point, scale, seed).mul(Signed::toSigned(2)));
    perlin = perlin.add(single_scale_perlin(point, scale*2, seed));
    perlin = perlin.add(single_scale_perlin(point, scale*4, seed));
    perlin = perlin.add(single_scale_perlin(point, scale*8, seed));
    perlin = perlin.div(Signed::toSigned(4));
    perlin = perlin.muli(PERLIN_MAX/2).add(Signed::toSigned(PERLIN_MAX/2));
    perlin.absi()
}

#[test]
fn test_random() {
    let perl1 = compute_perlin(Coords {x: Signed::toSigned(145), y: Signed::toSigned(10)}, 128, 10);
    std::println(perl1);

    let perl2 = compute_perlin(Coords {x: Signed::toSigned(146), y: Signed::toSigned(20)}, 128, 10);
    std::println(perl2);

    let perl3 = compute_perlin(Coords {x: Signed::toSigned(147), y: Signed::toSigned(20)}, 128, 10);
    std::println(perl3);
}