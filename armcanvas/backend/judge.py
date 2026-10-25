"""Gemini proxy so the API key never leaves the server."""
from __future__ import annotations

import json
import os

import httpx

from models import JudgeRequest, JudgeResult

MODEL = "gemini-2.5-flash"
TIMEOUT_S = 20


def _prompt(req: JudgeRequest) -> str:
    return (
        f"These images are front, side and top views of a single 3D line drawing made in the air "
        f"by someone doing arm rehabilitation. They were asked to draw: {req.template_name} "
        f"({req.instruction}). Respond with JSON only: "
        '{"guess": "<what the drawing looks like, 2-5 words>", '
        '"match": <0-10 integer, how well it matches the requested shape>, '
        '"feedback": "<one short encouraging sentence with one concrete tip about shape, size or smoothness>"}'
    )


async def judge(req: JudgeRequest) -> JudgeResult:
    key = os.environ.get("GOOGLE_API_KEY")
    if not key:
        raise RuntimeError("GOOGLE_API_KEY not set on server")
    parts: list[dict] = [{"text": _prompt(req)}]
    parts += [{"inline_data": {"mime_type": "image/png", "data": b64}} for b64 in req.images_png_b64]
    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {"response_mime_type": "application/json", "temperature": 0.4},
    }
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
    async with httpx.AsyncClient(timeout=TIMEOUT_S) as client:
        resp = await client.post(url, json=body, headers={"x-goog-api-key": key})
    if resp.status_code != 200:
        raise RuntimeError(f"Gemini HTTP {resp.status_code}: {resp.text[:200]}")
    text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
    return JudgeResult(**json.loads(text))
