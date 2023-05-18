use dep::std;
use dep::signed::Signed;

struct Coords {
    x: u120,
    y: u120,
}

impl Coords {
    fn diff(self, other: Self) -> Self {
        let mut diffx: u120 = 0;
        let mut diffy: u120 = 0;
        if self.x > other.x {
            diffx = self.x - other.x;
        } else {
            diffx = other.x - self.x;
        }

        if (self.y > other.y) {
            diffy = self.y - other.y;
        } else {
            diffy = other.y - self.y;
        }
        Self {
            x: diffx,
            y: diffy
        }
    }
}

global DENOMINATOR = 1125899906842624; //2^50
global PERLIN_MAX = 64;

// Return a psuedorandom integer in [0, 15]
fn random(x: u120, y: u120, scale: u120, seed: Field) -> u4 {
    let t = std::hash::mimc_bn254([x as Field, y as Field, scale as Field, seed]);

    let bits = t.to_le_bits(32);
    8*(bits[3] as u4) + 4*(bits[2] as u4) + 2*(bits[1] as u4) + (bits[0] as u4)
}

fn random_gradient_at(point: Coords, scale: u120, seed: Field) -> (Signed, Signed) {
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
    let rand = random(point.x, point.y, scale, seed);

    let mut direction = (Signed::zero(), Signed::zero());
    for i in 0..16 {
        if (i as u4 == rand) {
            direction = DIRECTIONS[i];
        }
    };

    (direction.0.muli(point.x), direction.1.muli(point.y))
}

fn get_weight(corner: Coords, point: Coords, scale: u120) -> u120 {
    let diff = corner.diff(point);
    let res = (scale - diff.x) * (scale - diff.y);

    res
}

fn get_corners(point: Coords, scale: u120) -> [Coords; 4] {
    let bottom_left = Coords {
        x: (point.x / scale) * scale,
        y: (point.y / scale) * scale,
    };

    [
        Coords { x: bottom_left.x, y: bottom_left.y },                  // BL
        Coords { x: bottom_left.x + scale, y: bottom_left.y },          // BR
        Coords { x: bottom_left.x, y: bottom_left.y + scale},           // TL
        Coords { x: bottom_left.x + scale, y: bottom_left.y + scale},   // TR
    ]
}

fn single_scale_perlin(point: Coords, scale: u120, seed: Field) -> Signed {
    let corners = get_corners(point, scale);

    let mut numerator = toSigned(0);
    for i in 0..4 {
        let corner = corners[i];
        let offsetx = toSigned(point.x).sub(toSigned(corner.x));
        let offsety = toSigned(point.y).sub(toSigned(corner.y));
        let offset = Coords {
            x: offsetx.x,
            y: offsety.x,
        };
        
        let gradient = random_gradient_at(offset, scale, seed);
        let dotx = gradient.0.muli(offset.x);
        let doty = gradient.1.muli(offset.y);
        let dot = dotx.add(doty);
        let weight = get_weight(corner, point, scale);

        let t = dot.muli(weight);
        numerator = numerator.add(t);
    }

    numerator.div(toSigned(scale * scale * scale))
}

fn compute_perlin(point: Coords, scale: u120, seed: Field) -> Signed {
    let mut perlin = toSigned(0);

    perlin = perlin.add(single_scale_perlin(point, scale, seed).mul(toSigned(2)));
    perlin = perlin.add(single_scale_perlin(point, scale*2, seed));
    perlin = perlin.add(single_scale_perlin(point, scale*4, seed));
    perlin = perlin.add(single_scale_perlin(point, scale*8, seed));
    perlin = perlin.div(toSigned(4));
    perlin = perlin.muli(PERLIN_MAX/2).add(toSigned(PERLIN_MAX/2));
    perlin
}

#[test]
fn test_random() {
    let (gx, gy) = random_gradient_at(Coords {x: 10, y: 20},4,16);
    
    let gxx = gx.x;
    let gyx = gy.x;
    std::println(gxx);
    std::println(gyx);

    let perl1 = compute_perlin(Coords {x: 145, y: 10}, 128, 10).x;
    std::println(perl1);

    let perl2 = compute_perlin(Coords {x: 146, y: 20}, 128, 10).x;
    std::println(perl2);

    let perl3 = compute_perlin(Coords {x: 147, y: 20}, 128, 10).x;
    std::println(perl3);
}