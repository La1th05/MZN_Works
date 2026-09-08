# services/symbol_recognizer.py
# Put your checkpoint here: services/models/best_symbol_cnn2.pt
# Recommended checkpoint format:
#   torch.save({"state_dict": model.state_dict(), "classes": train_dataset.classes}, path)

import base64
import io
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms


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


def _is_blank(rgba: np.ndarray, ink_threshold: int = 50) -> bool:
    if rgba is None:
        return True
    rgb = rgba[..., :3].astype(np.uint8)
    gray = np.mean(rgb, axis=2)
    # count "ink" pixels (not white)
    ink = int((gray < 245).sum())
    return ink < ink_threshold


@lru_cache(maxsize=1)
def load_symbol_model():
    ckpt_path = Path(__file__).resolve().parent / "models" / "best_symbol_cnn2.pt"
    ckpt = torch.load(str(ckpt_path), map_location=_device())

    classes = ckpt.get("classes")
    if not classes:
        # Fallback ONLY if you didn't save classes. Best is to save classes in ckpt.
        classes = ['0','1','2','3','4','5','6','7','8','9','+','-','*','/','=']

    model = BestCNN(num_classes=len(classes)).to(_device())
    model.load_state_dict(ckpt["state_dict"])
    model.eval()
    return model, classes


@torch.no_grad()
def predict_from_canvas(rgba: np.ndarray, topk: int = 3):
    """
    Args:
        rgba: HxWx4 numpy from st_canvas.image_data
    Returns:
        pred_token (str), confidence (float), topk_list [(token, prob)], png_b64 (str)
    """
    if rgba is None or _is_blank(rgba):
        return "", 0.0, [], ""

    model, classes = load_symbol_model()

    pil = Image.fromarray(rgba.astype(np.uint8), mode="RGBA").convert("RGB")
    x = infer_tf(pil).unsqueeze(0).to(_device())  # [1,1,28,28]

    logits = model(x)
    probs = F.softmax(logits, dim=1)[0]

    conf, idx = torch.max(probs, dim=0)
    pred = classes[int(idx)]

    k = min(int(topk), int(probs.numel()))
    top = torch.topk(probs, k=k)
    top_list = [(classes[int(i)], float(p)) for p, i in zip(top.values, top.indices)]

    png_b64 = _rgba_to_png_b64(rgba)
    return pred, float(conf), top_list, png_b64