# services/symbol_recognizer.py
# Checkpoint: services/models/best_symbol_cnn2.pt

import base64
import io
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms

# ---------------- Class & Label Mapping ----------------
LABEL_TO_SYMBOL = {
    'add': '+',
    'divide': '/',
    'eight': '8',
    'eq': '=',
    'five': '5',
    'four': '4',
    'multiply': '*',
    'nine': '9',
    'one': '1',
    'seven': '7',
    'six': '6',
    'subtract': '-',
    'three': '3',
    'two': '2',
    'zero': '0'
}

# ---------------- Model (same as training) ----------------
class BestCNN(nn.Module):
    def __init__(self, num_classes: int):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, 3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.MaxPool2d(2),

            nn.Conv2d(32, 64, 3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(2),

            nn.Conv2d(64, 128, 3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
            nn.MaxPool2d(2),

            nn.Conv2d(128, 256, 3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(),
            nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Linear(256, 256),
            nn.ReLU(),
            nn.Linear(256, num_classes),
        )

    def forward(self, x):
        return self.classifier(self.features(x))


# Must match training preprocessing:
# Grayscale(1) -> Resize(28,28) -> ToTensor -> Normalize(0.5,0.5)
infer_tf = transforms.Compose([
    transforms.Grayscale(1),
    transforms.Resize((28, 28)),
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,)),
])


def _device() -> str:
    return "cuda" if torch.cuda.is_available() else "cpu"


def _rgba_to_png_b64(rgba: np.ndarray) -> str:
    img = Image.fromarray(rgba.astype(np.uint8), mode="RGBA")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def _is_blank(rgba: np.ndarray, ink_threshold: int = 40) -> bool:
    if rgba is None or len(rgba) == 0:
        return True
    rgb = rgba[..., :3].astype(np.uint8)
    gray = np.mean(rgb, axis=2)
    # count "ink" pixels (pixels darker than 240)
    ink = int((gray < 240).sum())
    return ink < ink_threshold


@lru_cache(maxsize=1)
def load_symbol_model():
    ckpt_path = Path(__file__).resolve().parent / "models" / "best_symbol_cnn2.pt"
    if not ckpt_path.exists():
        alt_path = Path(__file__).resolve().parent.parent / "services" / "models" / "best_symbol_cnn2.pt"
        if alt_path.exists():
            ckpt_path = alt_path
        else:
            raise FileNotFoundError(f"Checkpoint not found at: {ckpt_path}")

    ckpt = torch.load(str(ckpt_path), map_location=_device(), weights_only=False)

    if isinstance(ckpt, dict) and "classes" in ckpt:
        classes = ckpt["classes"]
    else:
        classes = ['add', 'divide', 'eight', 'eq', 'five', 'four', 'multiply', 'nine', 'one', 'seven', 'six', 'subtract', 'three', 'two', 'zero']

    model = BestCNN(num_classes=len(classes)).to(_device())
    if isinstance(ckpt, dict) and "state_dict" in ckpt:
        model.load_state_dict(ckpt["state_dict"])
    elif isinstance(ckpt, dict):
        model.load_state_dict(ckpt)
    else:
        model = ckpt

    model.eval()
    return model, classes


def _should_merge_boxes(b1, b2):
    """
    Decide whether two bounding boxes belong to the same character.
    Rule 1: If both boxes are substantial vertical components (digits, h >= 20),
            and their horizontal centers are separated (>= 15px), NEVER merge!
    Rule 2: Vertically stacked strokes (like '=' or '5' top bar):
            high horizontal overlap (> 40%), separated vertically.
    Rule 3: One box is contained within the other.
    Rule 4: Tiny fragment / crossbar (h < 18 or w < 12) directly touching/intersecting.
    """
    x1_a, y1_a, x2_a, y2_a = b1
    x1_b, y1_b, x2_b, y2_b = b2
    w_a, h_a = x2_a - x1_a, y2_a - y1_a
    w_b, h_b = x2_b - x1_b, y2_b - y1_b
    if w_a <= 0 or h_a <= 0 or w_b <= 0 or h_b <= 0:
        return False

    cx_a, cy_a = (x1_a + x2_a) / 2.0, (y1_a + y2_a) / 2.0
    cx_b, cy_b = (x1_b + x2_b) / 2.0, (y1_b + y2_b) / 2.0

    # Adjacent distinct glyphs / digits MUST NOT be merged
    if h_a >= 20 and h_b >= 20 and abs(cx_a - cx_b) >= 15:
        return False

    # Containment
    if (x1_a <= x1_b and x2_a >= x2_b and y1_a <= y1_b and y2_a >= y2_b) or \
       (x1_b <= x1_a and x2_b >= x2_a and y1_b <= y1_a and y2_b >= y2_a):
        return True

    x_overlap = max(0, min(x2_a, x2_b) - max(x1_a, x1_b))
    y_overlap = max(0, min(y2_a, y2_b) - max(y1_a, y1_b))
    min_w = min(w_a, w_b)
    min_h = min(h_a, h_b)

    # Vertically stacked strokes (e.g. '=' or '5' top horizontal bar)
    if min_w > 0 and (x_overlap / min_w) > 0.40:
        v_gap = max(0, max(y1_a, y1_b) - min(y2_a, y2_b))
        if v_gap <= max(h_a, h_b) * 0.9 + 12:
            return True

    # Small stroke / crossbar (e.g. dot or cross stroke of '+')
    if (min_h < 18 or min_w < 12) and (x_overlap > 0 or abs(cx_a - cx_b) < 14):
        if y_overlap > 0 or abs(cy_a - cy_b) < max(h_a, h_b) * 0.6:
            return True

    return False


def _merge_character_boxes(boxes):
    """
    Cluster and merge disconnected strokes that form a single glyph.
    Does NOT merge side-by-side digits.
    """
    if not boxes:
        return []

    merged = list(boxes)
    changed = True
    while changed:
        changed = False
        new_merged = []
        skip = set()
        for i in range(len(merged)):
            if i in skip:
                continue
            b1 = merged[i]
            for j in range(i + 1, len(merged)):
                if j in skip:
                    continue
                b2 = merged[j]
                if _should_merge_boxes(b1, b2):
                    b1 = (
                        min(b1[0], b2[0]),
                        min(b1[1], b2[1]),
                        max(b1[2], b2[2]),
                        max(b1[3], b2[3])
                    )
                    skip.add(j)
                    changed = True
            new_merged.append(b1)
        merged = new_merged

    return merged


def _segment_characters(pil_img: Image.Image):
    """
    Detect individual character bounding boxes ordered from left to right.
    Also handles splitting touching characters when aspect ratio is wide.
    Returns list of (min_x, min_y, max_x, max_y).
    """
    gray = np.array(pil_img.convert("L"))
    # Dark ink mask (black ink on white canvas)
    ink_mask = (gray < 220).astype(np.uint8)

    # Label connected components
    labeled, num_features = ndimage.label(ink_mask)
    if num_features == 0:
        return []

    slices = ndimage.find_objects(labeled)
    raw_boxes = []
    for s in slices:
        y1, y2 = s[0].start, s[0].stop
        x1, x2 = s[1].start, s[1].stop
        # Filter out tiny noise specks
        if (x2 - x1) * (y2 - y1) >= 20 and (y2 - y1) >= 6:
            raw_boxes.append((x1, y1, x2, y2))

    if not raw_boxes:
        return []

    # Merge multi-stroke parts of the same glyph
    merged_boxes = _merge_character_boxes(raw_boxes)

    # Check for touching digits (wide bounding box) and split by vertical projection
    final_boxes = []
    for b in merged_boxes:
        w = b[2] - b[0]
        h = b[3] - b[1]
        if w > 1.05 * h and w >= 36:
            sub_mask = ink_mask[b[1]:b[3], b[0]:b[2]]
            col_sums = sub_mask.sum(axis=0)
            mid_start = int(w * 0.25)
            mid_end = int(w * 0.75)
            if mid_end > mid_start:
                split_x = mid_start + int(np.argmin(col_sums[mid_start:mid_end]))
                left_peak = np.max(col_sums[:split_x]) if split_x > 0 else 1
                right_peak = np.max(col_sums[split_x:]) if split_x < w else 1
                valley = col_sums[split_x]
                if valley <= 0.85 * min(left_peak, right_peak):
                    final_boxes.append((b[0], b[1], b[0] + split_x, b[3]))
                    final_boxes.append((b[0] + split_x, b[1], b[2], b[3]))
                    continue
        final_boxes.append(b)

    # Sort strictly left-to-right by horizontal center
    final_boxes.sort(key=lambda b: (b[0] + b[2]) / 2)
    return final_boxes


@torch.no_grad()
def _classify_cropped_glyph(crop: Image.Image, model, classes, topk: int = 3, digits_only: bool = True):
    """
    Tightly crop to ink bounding box, pad to square, resize to 28x28, and run CNN.
    """
    # 1. Tightly crop around ink inside the bounding box
    crop_gray = np.array(crop.convert("L"))
    ink_ys, ink_xs = np.where(crop_gray < 220)
    if len(ink_xs) > 0 and len(ink_ys) > 0:
        crop = crop.crop((
            int(ink_xs.min()),
            int(ink_ys.min()),
            int(ink_xs.max()) + 1,
            int(ink_ys.max()) + 1
        ))

    w, h = crop.size
    max_dim = max(w, h, 28)
    # Pad to square with white background and standard 25% margin
    pad = int(max_dim * 0.25)
    full_dim = max_dim + 2 * pad
    sq = Image.new("RGB", (full_dim, full_dim), (255, 255, 255))
    sq.paste(crop, ((full_dim - w) // 2, (full_dim - h) // 2))

    x = infer_tf(sq).unsqueeze(0).to(_device())
    logits = model(x)
    probs = F.softmax(logits, dim=1)[0]

    if digits_only:
        # Constrain prediction to numeric digits (0-9)
        digit_indices = [i for i, c in enumerate(classes) if LABEL_TO_SYMBOL.get(c, c).isdigit()]
        if digit_indices:
            sub_probs = probs[digit_indices]
            best_sub_idx = int(torch.argmax(sub_probs).item())
            idx = digit_indices[best_sub_idx]
            conf = probs[idx]
        else:
            conf, idx = torch.max(probs, dim=0)
    else:
        conf, idx = torch.max(probs, dim=0)

    raw_label = classes[int(idx)]
    symbol = LABEL_TO_SYMBOL.get(raw_label, raw_label)

    k = min(int(topk), int(probs.numel()))
    top = torch.topk(probs, k=k)
    top_list = [
        {
            "label": classes[int(i)],
            "symbol": LABEL_TO_SYMBOL.get(classes[int(i)], classes[int(i)]),
            "confidence": round(float(p), 4)
        }
        for p, i in zip(top.values, top.indices)
    ]

    return {
        "symbol": symbol,
        "raw_label": raw_label,
        "confidence": round(float(conf), 4),
        "top_predictions": top_list
    }


@torch.no_grad()
def predict_from_pil(pil_img: Image.Image, topk: int = 5, digits_only: bool = True):
    """
    Predict symbol(s) from PIL Image with multi-character segmentation support.
    Supports single digits and multi-digit numbers (e.g. 73, 15, 29, 34).
    """
    # 1. Handle transparency if present: composite over solid white
    if pil_img.mode in ("RGBA", "LA") or (pil_img.mode == "P" and "transparency" in pil_img.info):
        bg = Image.new("RGB", pil_img.size, (255, 255, 255))
        rgba_img = pil_img.convert("RGBA")
        bg.paste(rgba_img, mask=rgba_img.split()[3])
        pil_rgb = bg
    else:
        pil_rgb = pil_img.convert("RGB")

    # 2. Check for blank image
    gray_arr = np.mean(np.array(pil_rgb), axis=2)
    ink_count = int((gray_arr < 240).sum())
    if ink_count < 25:
        return {
            "symbol": "",
            "raw_label": "",
            "confidence": 0.0,
            "top_predictions": [],
            "tokens": [],
            "is_blank": True
        }

    model, classes = load_symbol_model()

    # 3. Detect character bounding boxes from left to right
    boxes = _segment_characters(pil_rgb)

    if not boxes:
        # Fallback to full image
        res = _classify_cropped_glyph(pil_rgb, model, classes, topk=topk, digits_only=digits_only)
        res["tokens"] = [res]
        res["is_blank"] = False
        return res

    # 4. Classify each detected character
    token_results = []
    margin = 8
    for b in boxes:
        x1 = max(0, b[0] - margin)
        y1 = max(0, b[1] - margin)
        x2 = min(pil_rgb.width, b[2] + margin)
        y2 = min(pil_rgb.height, b[3] + margin)
        crop = pil_rgb.crop((x1, y1, x2, y2))

        pred = _classify_cropped_glyph(crop, model, classes, topk=topk, digits_only=digits_only)
        token_results.append(pred)

    # 5. Aggregate results (concatenate symbols)
    full_symbol = "".join(t["symbol"] for t in token_results)
    full_label = " ".join(t["raw_label"] for t in token_results)
    avg_conf = round(sum(t["confidence"] for t in token_results) / max(1, len(token_results)), 4)

    print(f"[CNN] Segmented into {len(boxes)} box(es) -> Final Recognized: '{full_symbol}' (conf: {avg_conf})")

    return {
        "symbol": full_symbol,
        "raw_label": full_label,
        "confidence": avg_conf,
        "tokens": token_results,
        "top_predictions": token_results[0]["top_predictions"] if token_results else [],
        "is_blank": False
    }


@torch.no_grad()
def predict_from_canvas(rgba: np.ndarray, topk: int = 3, digits_only: bool = True):
    """
    Backward-compatible method for Streamlit / canvas numpy array.
    """
    if rgba is None or _is_blank(rgba):
        return "", 0.0, [], ""

    pil = Image.fromarray(rgba.astype(np.uint8), mode="RGBA")
    res = predict_from_pil(pil, topk=topk, digits_only=digits_only)
    png_b64 = _rgba_to_png_b64(rgba)

    top_tuples = [(t["label"], t["confidence"]) for t in res.get("top_predictions", [])]
    return res["raw_label"], res["confidence"], top_tuples, png_b64


@torch.no_grad()
def predict_from_base64(b64_str: str, topk: int = 5, digits_only: bool = True):
    """
    Decodes base64 PNG/JPEG and runs multi-character prediction.
    """
    if "," in b64_str:
        b64_str = b64_str.split(",", 1)[1]

    img_bytes = base64.b64decode(b64_str)
    pil_img = Image.open(io.BytesIO(img_bytes))
    return predict_from_pil(pil_img, topk=topk, digits_only=digits_only)