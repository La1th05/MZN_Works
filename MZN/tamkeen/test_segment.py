import numpy as np
from PIL import Image, ImageDraw
import sys
sys.path.insert(0, '.')
from smart_lms.services.symbol_recognizer import load_symbol_model, _classify_cropped_glyph

def should_merge(box1, box2):
    x1_a, y1_a, x2_a, y2_a = box1
    x1_b, y1_b, x2_b, y2_b = box2
    w_a, h_a = x2_a - x1_a, y2_a - y1_a
    w_b, h_b = x2_b - x1_b, y2_b - y1_b

    x_overlap = max(0, min(x2_a, x2_b) - max(x1_a, x1_b))
    y_overlap = max(0, min(y2_a, y2_b) - max(y1_a, y1_b))
    min_w = min(w_a, w_b)
    min_h = min(h_a, h_b)

    # 1. High horizontal overlap (e.g. stacked like '=' or '5' top bar)
    if min_w > 0 and (x_overlap / min_w) > 0.35:
        v_gap = max(0, max(y1_a, y1_b) - min(y2_a, y2_b))
        if v_gap <= max(h_a, h_b) * 0.75 + 15:
            return True

    # 2. Bounding box intersection (strokes crossing or touching)
    if x_overlap > 0 and y_overlap > 0:
        area_overlap = x_overlap * y_overlap
        if area_overlap / (min_w * min_h) > 0.15:
            return True

    return False

def merge_boxes(boxes):
    if not boxes:
        return []
    
    # Graph-connected components merge
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
                if should_merge(b1, b2):
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

    # Sort left to right by center_x
    merged.sort(key=lambda b: (b[0] + b[2]) / 2)
    return merged

# Test cases
box7 = (90, 60, 140, 180)
box3 = (150, 60, 195, 180)
print('7 and 3:', merge_boxes([box7, box3]))

eq1 = (100, 80, 140, 90)
eq2 = (102, 105, 138, 115)
print('Equal sign:', merge_boxes([eq1, eq2]))

five1 = (100, 50, 140, 60)
five2 = (105, 58, 145, 130)
print('Digit 5 with 2 strokes:', merge_boxes([five1, five2]))
