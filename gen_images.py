#!/usr/bin/env python3
"""
Generate marketing images for the Pulse Internet Speed Test landing page
using Imagen 3 on Vertex AI (demos-416206 project).

Usage:
    python gen_images.py
    python gen_images.py --image hero        # single image
    python gen_images.py --out ./my-dir     # custom output dir

Output goes to ./pulse-assets/ by default.
Requires: pip install google-cloud-aiplatform pillow
Auth:     gcloud auth application-default login
"""

import argparse
import base64
import os
import sys
from pathlib import Path

PROJECT_ID = "demos-416206"
LOCATION = "us-central1"
MODEL = "imagen-3.0-generate-002"

IMAGES = {
    "hero": {
        "prompt": (
            "A sleek, minimal dark-background illustration of a circular speedometer gauge "
            "with a cyan/teal glowing needle pointing to the right, surrounded by subtle "
            "concentric arcs. Clean tech aesthetic, no text, no UI chrome, "
            "suitable as a hero image for an iOS speed test app. "
            "High contrast, professional, dark navy background."
        ),
        "filename": "hero.png",
        "aspect": "16:9",
    },
    "download_upload": {
        "prompt": (
            "Minimal flat icon illustration: two bold arrows, one pointing down in cyan/teal "
            "and one pointing up in dark charcoal, side by side on a white background. "
            "Clean, geometric, no gradients, suitable for a feature card on a tech website."
        ),
        "filename": "feature_download_upload.png",
        "aspect": "1:1",
    },
    "ping_jitter": {
        "prompt": (
            "Minimal flat icon illustration: a clean waveform or pulse signal line in amber/orange "
            "on a white background, representing network latency. "
            "Geometric, no text, suitable for a feature card on a tech website."
        ),
        "filename": "feature_ping_jitter.png",
        "aspect": "1:1",
    },
    "isp": {
        "prompt": (
            "Minimal flat icon illustration: a wifi signal icon with a subtle location pin "
            "in cyan/teal on a white background, representing ISP or network provider detection. "
            "Clean, geometric, no gradients, no text, suitable for a feature card on a tech website."
        ),
        "filename": "feature_isp.png",
        "aspect": "1:1",
    },
    "history": {
        "prompt": (
            "Minimal flat icon illustration: a simple bar chart or list with a clock symbol "
            "in dark charcoal on a white background, representing test history or records over time. "
            "Clean, geometric, no gradients, no text, suitable for a feature card on a tech website."
        ),
        "filename": "feature_history.png",
        "aspect": "1:1",
    },
}


def generate(image_key: str, out_dir: Path) -> Path:
    from google.cloud import aiplatform
    from vertexai.preview.vision_models import ImageGenerationModel

    aiplatform.init(project=PROJECT_ID, location=LOCATION)
    model = ImageGenerationModel.from_pretrained(MODEL)

    cfg = IMAGES[image_key]
    print(f"  Generating '{image_key}'...")

    result = model.generate_images(
        prompt=cfg["prompt"],
        number_of_images=1,
        aspect_ratio=cfg["aspect"],
        safety_filter_level="block_few",
        person_generation="dont_allow",
    )

    out_path = out_dir / cfg["filename"]
    result.images[0].save(str(out_path))
    print(f"  Saved → {out_path}")
    return out_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", choices=list(IMAGES.keys()), help="Generate a single image by key")
    parser.add_argument("--out", default="./pulse-assets", help="Output directory (default: ./pulse-assets)")
    args = parser.parse_args()

    try:
        import vertexai  # noqa: F401
    except ImportError:
        print("Missing dependency. Run:  pip install google-cloud-aiplatform")
        sys.exit(1)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    keys = [args.image] if args.image else list(IMAGES.keys())

    print(f"Project: {PROJECT_ID}  Model: {MODEL}")
    print(f"Output:  {out_dir.resolve()}\n")

    for key in keys:
        generate(key, out_dir)

    print(f"\nDone. {len(keys)} image(s) written to {out_dir.resolve()}")


if __name__ == "__main__":
    main()
