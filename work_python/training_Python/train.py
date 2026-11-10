"""
EE4322 Final Project - AI accelerator for handwritten digits (DE2-115)
Offline part: train the 64 -> 16 -> 10 network, quantize it to integers,
check an integer-only reference model, and export files for Quartus.

Run:  python train.py
Outputs go to ./out/
"""
import os
import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.neural_network import MLPClassifier

SEED = 42            # fixed seed so training is repeatable
THRESHOLD = 6        # load_digits pixels are 0..16; >= THRESHOLD becomes 1
HIDDEN = 32
SHIFT = 16           # requantization: h_q = (acc1 * M1) >> SHIFT
N_TEST_VECTORS = 50
AUGMENT = True       # add 1-cell shifted copies (helps with off-center drawings,
                     # costs ~1-2% on the centered test set; set False to compare)
THIN = True          # also train on copies thinned to 1-cell-wide strokes, because
                     # people clicking cells on the grid draw thin lines while the
                     # dataset strokes are 2-3 cells thick
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


# ---------------------------------------------------------------- data
def load_binary_digits():
    """8x8 digits, binarized like the VGA drawing grid (each cell 0 or 1)."""
    d = load_digits()
    X = (d.images >= THRESHOLD).astype(np.int64)      # shape (N, 8, 8)
    return X, d.target


def shift_image(img, dy, dx):
    """Move an 8x8 image by (dy, dx) cells, filling with zeros."""
    out = np.zeros_like(img)
    h, w = img.shape
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = img[ys, xs]
    return out


def thin(img):
    """
    Zhang-Suen thinning: peel pixels off the edges of each stroke until it is
    1 cell wide, without breaking it apart. Makes dataset digits look like
    digits drawn by clicking cells on the VGA grid.
    """
    im = np.pad(img.copy(), 1)
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            remove = []
            for r in range(1, im.shape[0] - 1):
                for c in range(1, im.shape[1] - 1):
                    if not im[r, c]:
                        continue
                    # 8 neighbours, clockwise from the top
                    p = [im[r-1, c], im[r-1, c+1], im[r, c+1], im[r+1, c+1],
                         im[r+1, c], im[r+1, c-1], im[r, c-1], im[r-1, c-1]]
                    B = sum(p)                                              # filled neighbours
                    A = sum(p[i] == 0 and p[(i + 1) % 8] == 1 for i in range(8))  # 0->1 transitions
                    if not (2 <= B <= 6 and A == 1):
                        continue
                    if step == 0 and p[0]*p[2]*p[4] == 0 and p[2]*p[4]*p[6] == 0:
                        remove.append((r, c))
                    if step == 1 and p[0]*p[2]*p[6] == 0 and p[0]*p[4]*p[6] == 0:
                        remove.append((r, c))
            for r, c in remove:
                im[r, c] = 0
            changed |= bool(remove)
    return im[1:-1, 1:-1]


def augment(X, y):
    """Add copies shifted by one cell, since people won't draw perfectly centered."""
    Xs, ys = [X], [y]
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        Xs.append(np.array([shift_image(im, dy, dx) for im in X]))
        ys.append(y)
    return np.concatenate(Xs), np.concatenate(ys)


# ---------------------------------------------------------------- quantization
def quantize_model(mlp, X_cal):
    """
    Turn float weights into the integers the FPGA will use.

    Input pixels are 0/1 integers (scale 1).
    Layer 1:  acc1 = sum(x * W1q) + b1q              (32-bit signed)
              h_q  = clamp((max(acc1,0) * M1) >> SHIFT, 0, 127)   (ReLU + rescale to int8)
    Layer 2:  acc2 = sum(h_q * W2q) + b2q            (32-bit signed)
    Output:   digit = argmax(acc2)
    """
    W1, W2 = mlp.coefs_            # W1: (64,16)  W2: (16,10)
    b1, b2 = mlp.intercepts_

    s_w1 = np.abs(W1).max() / 127.0
    s_w2 = np.abs(W2).max() / 127.0
    W1q = np.round(W1 / s_w1).astype(np.int64)
    W2q = np.round(W2 / s_w2).astype(np.int64)
    b1q = np.round(b1 / s_w1).astype(np.int64)            # input scale is 1

    # Pick the hidden-layer scale from the largest activation seen on real data
    h_float = np.maximum(X_cal @ W1 + b1, 0)
    s_h = h_float.max() / 127.0
    M1 = int(round(s_w1 / s_h * (1 << SHIFT)))
    b2q = np.round(b2 / (s_h * s_w2)).astype(np.int64)

    return dict(W1q=W1q, b1q=b1q, W2q=W2q, b2q=b2q, M1=M1)


def int_inference(x, q):
    """
    Bit-exact integer model of the hardware. Every value here is an integer;
    the SystemVerilog design must produce the same acc1, h_q, acc2 and digit.
    """
    acc1 = x @ q["W1q"] + q["b1q"]                         # int32 accumulators
    relu = np.maximum(acc1, 0)
    h_q = np.clip((relu * q["M1"]) >> SHIFT, 0, 127)       # >> is arithmetic shift (floor)
    acc2 = h_q @ q["W2q"] + q["b2q"]
    return acc1, h_q, acc2, np.argmax(acc2, axis=-1)       # ties -> lowest index


def check_ranges(X, q):
    """Make sure nothing overflows the bit widths we plan to use in hardware."""
    acc1, h_q, acc2, _ = int_inference(X, q)
    worst = max(np.abs(acc1).max() * q["M1"], np.abs(acc2).max())
    assert np.abs(q["W1q"]).max() <= 127 and np.abs(q["W2q"]).max() <= 127
    assert worst < 2**31, "32-bit overflow: lower SHIFT"
    return int(np.abs(acc1).max()), int(np.abs(acc2).max()), int(worst)


# ---------------------------------------------------------------- export
def write_mif(path, values, width):
    """Quartus Memory Initialization File, two's complement, hex data."""
    mask = (1 << width) - 1
    digits = (width + 3) // 4
    with open(path, "w") as f:
        f.write(f"WIDTH={width};\nDEPTH={len(values)};\n")
        f.write("ADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\n\nCONTENT BEGIN\n")
        for a, v in enumerate(values):
            f.write(f"    {a} : {int(v) & mask:0{digits}X};\n")
        f.write("END;\n")


def export(q, X_test, y_test):
    os.makedirs(OUT, exist_ok=True)
    # Weight ordering: output neuron first, then input index -> addr = n*N_IN + i
    write_mif(os.path.join(OUT, "w1.mif"), q["W1q"].T.flatten(), 8)    # HIDDEN*64 words (1024 for 16 neurons)
    write_mif(os.path.join(OUT, "w2.mif"), q["W2q"].T.flatten(), 8)    # 10*HIDDEN words (160 for 16 neurons)
    write_mif(os.path.join(OUT, "b1.mif"), q["b1q"], 32)
    write_mif(os.path.join(OUT, "b2.mif"), q["b2q"], 32)

    with open(os.path.join(OUT, "nn_params_pkg.sv"), "w") as f:
        f.write("// Generated by train.py - do not edit by hand\n")
        f.write("package nn_params_pkg;\n")
        f.write("  localparam int N_IN     = 64;\n")
        f.write(f"  localparam int N_HID    = {HIDDEN};\n")
        f.write("  localparam int N_OUT    = 10;\n")
        f.write(f"  localparam int M1       = {q['M1']};   // requant multiplier\n")
        f.write(f"  localparam int SHIFT    = {SHIFT};   // h_q = (relu(acc1) * M1) >>> SHIFT, clamp 0..127\n")
        f.write("endpackage\n")

    # Test vectors for the SystemVerilog testbench: 64 pixel bits, expected digit, expected logits
    _, _, acc2, pred = int_inference(X_test[:N_TEST_VECTORS], q)
    with open(os.path.join(OUT, "test_vectors.txt"), "w") as f:
        f.write("# pixels(64 bits, row 0 first) label expected_digit logit0..logit9\n")
        for x, lab, p, lg in zip(X_test[:N_TEST_VECTORS], y_test, pred, acc2):
            f.write("".join(str(int(b)) for b in x) + f" {lab} {p} " + " ".join(str(int(v)) for v in lg) + "\n")


def show(img):
    return "\n".join("".join("#" if c else "." for c in row) for row in img)


# ---------------------------------------------------------------- main
def build():
    """Load data, train, quantize. Returns everything main() and other scripts need."""
    X_img, y = load_binary_digits()
    Xtr_img, Xte_img, ytr, yte = train_test_split(X_img, y, test_size=0.2, random_state=SEED, stratify=y)
    Xte_thin = np.array([thin(im) for im in Xte_img])      # thin-stroke version of the test set
    if THIN:
        Xtr_img = np.concatenate([Xtr_img, np.array([thin(im) for im in Xtr_img])])
        ytr = np.concatenate([ytr, ytr])
    if AUGMENT:
        Xtr_img, ytr = augment(Xtr_img, ytr)
    Xtr = Xtr_img.reshape(len(Xtr_img), 64)
    Xte = Xte_img.reshape(len(Xte_img), 64)

    mlp = MLPClassifier(hidden_layer_sizes=(HIDDEN,), activation="relu", max_iter=2000,
                        alpha=1e-2, random_state=SEED)
    mlp.fit(Xtr, ytr)
    q = quantize_model(mlp, Xtr.astype(float))
    return dict(mlp=mlp, q=q, Xtr=Xtr, ytr=ytr, Xte=Xte, yte=yte,
                Xte_thin=Xte_thin.reshape(-1, 64), Xtr_img=Xtr_img)


def main():
    r = build()
    mlp, q, Xtr, ytr, Xte, yte = r["mlp"], r["q"], r["Xtr"], r["ytr"], r["Xte"], r["yte"]
    print("Example training image (label %d):\n%s\n" % (ytr[0], show(r["Xtr_img"][0])))

    acc_float = mlp.score(Xte, yte)
    max_acc1, max_acc2, worst = check_ranges(np.concatenate([Xtr, Xte]), q)
    _, _, _, pred_int = int_inference(Xte, q)
    acc_int = (pred_int == yte).mean()
    acc_thin = (int_inference(r["Xte_thin"], q)[3] == yte).mean()
    agree = (pred_int == mlp.predict(Xte)).mean()

    print(f"Train images: {len(Xtr)}   Test images: {len(Xte)}")
    print(f"Float model test accuracy:   {acc_float:.3f}")
    print(f"Integer model test accuracy: {acc_int:.3f}")
    print(f"Integer, thin-stroke test:   {acc_thin:.3f}   (test digits thinned to 1 cell, like grid drawings)")
    print(f"Integer vs float agreement:  {agree:.3f}")
    print(f"M1 = {q['M1']}, SHIFT = {SHIFT}")
    print(f"Largest |acc1| = {max_acc1}, |acc2| = {max_acc2}, largest product = {worst} (< 2^31 OK)")

    export(q, Xte, yte)
    print(f"\nWrote w1.mif, w2.mif, b1.mif, b2.mif, nn_params_pkg.sv, test_vectors.txt to {OUT}")


if __name__ == "__main__":
    main()
