import io
import os
import json
import logging
from PIL import Image, ImageOps
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

PROCESSED_BUCKET = os.environ.get("PROCESSED_BUCKET", "")
WEBP_QUALITY = int(os.environ.get("WEBP_QUALITY", "80"))

SIZES = {
    "small": 320,
    "medium": 768,
    "large": 1280,
}


def _target_key(src_key: str, variant: str, ext: str = "webp") -> str:
    # products/raw/YYYY/MM/uuid.jpg -> products/<variant>/YYYY/MM/uuid.webp
    key = src_key
    if "/raw/" in key:
        key = key.replace("/raw/", f"/{variant}/", 1)
    else:
        parts = key.split("/")
        if len(parts) >= 2:
            key = "/".join([parts[0], variant] + parts[1:])
        else:
            key = f"products/{variant}/{key}"

    root = key.rsplit(".", 1)[0]
    return f"{root}.{ext}"


def _original_key(src_key: str) -> str:
    if "/raw/" in src_key:
        return src_key.replace("/raw/", "/original/", 1)
    return f"products/original/{src_key}"


def _normalize_image(body: bytes) -> Image.Image:
    image = Image.open(io.BytesIO(body))
    image = ImageOps.exif_transpose(image)
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGB")
    return image


def _resize(img: Image.Image, width: int) -> Image.Image:
    if img.width <= width:
        return img.copy()
    ratio = width / float(img.width)
    height = int(img.height * ratio)
    return img.resize((width, height), Image.Resampling.LANCZOS)


def _put_webp(bucket: str, key: str, img: Image.Image):
    out = io.BytesIO()
    img.save(out, format="WEBP", quality=WEBP_QUALITY, method=6)
    out.seek(0)
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=out,
        ContentType="image/webp",
        CacheControl="public, max-age=31536000, immutable",
    )


def lambda_handler(event, context):
    if not PROCESSED_BUCKET:
        raise RuntimeError("PROCESSED_BUCKET env is required")

    logger.info("event=%s", json.dumps(event))

    for record in event.get("Records", []):
        src_bucket = record["s3"]["bucket"]["name"]
        src_key = record["s3"]["object"]["key"]

        if not src_key.lower().endswith((".jpg", ".jpeg", ".png", ".webp", ".heic")):
            logger.info("skip non-image key=%s", src_key)
            continue

        obj = s3.get_object(Bucket=src_bucket, Key=src_key)
        body = obj["Body"].read()

        img = _normalize_image(body)

        # original sakla (opsiyonel)
        original_key = _original_key(src_key)
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=original_key,
            Body=body,
            ContentType=obj.get("ContentType", "application/octet-stream"),
            CacheControl="public, max-age=31536000, immutable",
        )

        for variant, width in SIZES.items():
            resized = _resize(img, width)
            target = _target_key(src_key, variant, "webp")
            _put_webp(PROCESSED_BUCKET, target, resized)

        logger.info("processed key=%s", src_key)

    return {"ok": True}
