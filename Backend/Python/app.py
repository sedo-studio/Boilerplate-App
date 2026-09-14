"""
TheSwiftKit — Python Flask AI Backend
======================================
A lightweight Flask server that proxies requests from the iOS app to a Large
Language Model provider. This keeps your API key server-side and exposes a
clean, provider-agnostic REST interface to the app.

Supported providers (set LLM_PROVIDER in .env):
    - "openai"  → OpenAI (GPT-4o, gpt-image-1.5)        [default]
    - "gemini"  → Google Gemini (gemini-2.5-flash, Imagen)

The endpoints and their JSON request/response shapes are IDENTICAL regardless
of provider, so the iOS client (AIApiClient.swift) never needs to change when
you switch providers.

Endpoints:
    POST /v1/chat    — Text chat completion
    POST /v1/images  — Image generation
    POST /v1/vision  — Image analysis / vision
    GET  /health      — Health check (reports the active provider + models)

Setup:
    1. Copy .env.example to .env and set LLM_PROVIDER + the matching API key
       (OPENAI_API_KEY or GEMINI_API_KEY).
    2. pip install -r requirements.txt
    3. python app.py
"""

import base64
import json
import os
import traceback

from flask import Flask, jsonify, request, Response
from flask_cors import CORS
from dotenv import load_dotenv

# Load environment variables from .env file (if present)
load_dotenv()

# ---------------------------------------------------------------------------
# OpenAI SDK import — gracefully handle missing package
# ---------------------------------------------------------------------------
try:
    from openai import OpenAI, APIError, APIConnectionError, RateLimitError, APITimeoutError
except ImportError:  # pragma: no cover
    OpenAI = None
    APIError = Exception
    APIConnectionError = Exception
    RateLimitError = Exception
    APITimeoutError = Exception

# ---------------------------------------------------------------------------
# Google Gemini SDK import — gracefully handle missing package
# ---------------------------------------------------------------------------
try:
    import google.generativeai as genai
except ImportError:  # pragma: no cover
    genai = None

# ---------------------------------------------------------------------------
# Configuration (all overridable via environment variables)
# ---------------------------------------------------------------------------
# Which provider powers the AI endpoints: "openai" (default) or "gemini".
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "openai").strip().lower()

# ---- OpenAI ----
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "")  # optional override for proxies
OPENAI_CHAT_MODEL = os.environ.get("OPENAI_CHAT_MODEL", "gpt-4o")
OPENAI_IMAGE_MODEL = os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1.5")
OPENAI_VISION_MODEL = os.environ.get("OPENAI_VISION_MODEL", "gpt-4o")

# ---- Gemini ----
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_CHAT_MODEL = os.environ.get("GEMINI_CHAT_MODEL", "gemini-2.5-flash")
GEMINI_IMAGE_MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "imagen-3.0-generate-002")
GEMINI_VISION_MODEL = os.environ.get("GEMINI_VISION_MODEL", "gemini-2.5-flash")

# Limits
MAX_CHAT_MESSAGES = 50          # Max messages in a single chat request
MAX_IMAGE_SIZE_BYTES = 20_000_000  # 20 MB max for vision image uploads
MAX_IMAGE_COUNT = 4             # Max images per generation request


def active_models() -> dict:
    """Return the chat/image/vision model names for the active provider."""
    if LLM_PROVIDER == "gemini":
        return {"chat": GEMINI_CHAT_MODEL, "image": GEMINI_IMAGE_MODEL, "vision": GEMINI_VISION_MODEL}
    return {"chat": OPENAI_CHAT_MODEL, "image": OPENAI_IMAGE_MODEL, "vision": OPENAI_VISION_MODEL}


# ---------------------------------------------------------------------------
# Flask app setup
# ---------------------------------------------------------------------------
app = Flask(__name__)

# CORS — allow all origins for development.
# In production, restrict this to your app's domain or use a reverse proxy.
# Example: CORS(app, origins=["https://yourapp.com"])
CORS(app)

# ---------------------------------------------------------------------------
# Rate Limiting (recommendations)
# ---------------------------------------------------------------------------
# For production, add rate limiting to protect against abuse. Options:
#   - flask-limiter: pip install flask-limiter
#     from flask_limiter import Limiter
#     limiter = Limiter(app, default_limits=["60 per minute"])
#   - Reverse proxy rate limiting (nginx, Cloudflare, etc.)
#   - The provider's own rate limits will also apply as a backstop.
# ---------------------------------------------------------------------------


# ===========================================================================
# OpenAI provider helpers
# ===========================================================================
def get_openai_client() -> "OpenAI":
    """
    Create and return an OpenAI client instance.
    Raises RuntimeError if the SDK is missing or the API key is not configured.
    """
    if OpenAI is None:
        raise RuntimeError(
            "The 'openai' package is not installed. Run: pip install openai"
        )
    if not OPENAI_API_KEY:
        raise RuntimeError(
            "OPENAI_API_KEY environment variable is not set. "
            "Create a .env file or export the variable."
        )
    kwargs = {"api_key": OPENAI_API_KEY}
    if OPENAI_BASE_URL:
        kwargs["base_url"] = OPENAI_BASE_URL
    return OpenAI(**kwargs)


# ===========================================================================
# Gemini provider helpers
# ===========================================================================
_gemini_configured = False


def _ensure_gemini() -> None:
    """
    Configure the Gemini SDK once. Raises RuntimeError if the SDK is missing or
    the API key is not configured.
    """
    global _gemini_configured
    if genai is None:
        raise RuntimeError(
            "The 'google-generativeai' package is not installed. "
            "Run: pip install google-generativeai"
        )
    if not GEMINI_API_KEY:
        raise RuntimeError(
            "GEMINI_API_KEY environment variable is not set. "
            "Create a .env file or export the variable."
        )
    if not _gemini_configured:
        genai.configure(api_key=GEMINI_API_KEY)
        _gemini_configured = True


def _gemini_resolve_chat_model(requested: str) -> str:
    """
    The iOS client may send an OpenAI-style model name (e.g. "gpt-4o-mini").
    When running under the Gemini provider we ignore non-Gemini model names and
    fall back to the configured Gemini chat model.
    """
    if requested and requested.lower().startswith("gemini"):
        return requested
    return GEMINI_CHAT_MODEL


def gemini_chat(messages: list, model: str, temperature: float) -> str:
    """Run a chat completion through Gemini, returning the reply text."""
    _ensure_gemini()

    # Gemini takes the system prompt separately, and uses role "model" for the
    # assistant's turns. Map the OpenAI-style messages accordingly.
    system_parts = [m.get("content", "") for m in messages if m.get("role") == "system"]
    system_instruction = "\n".join(p for p in system_parts if p) or None

    contents = []
    for m in messages:
        role = m.get("role")
        if role == "system":
            continue
        gemini_role = "model" if role == "assistant" else "user"
        contents.append({"role": gemini_role, "parts": [m.get("content", "")]})

    gen_model = genai.GenerativeModel(
        model_name=_gemini_resolve_chat_model(model),
        system_instruction=system_instruction,
    )
    resp = gen_model.generate_content(
        contents,
        generation_config=genai.types.GenerationConfig(temperature=temperature),
    )
    return getattr(resp, "text", "") or ""


def gemini_vision(prompt: str, img_bytes: bytes, mime_type: str) -> str:
    """Analyze an image through Gemini's native multimodal model."""
    _ensure_gemini()
    gen_model = genai.GenerativeModel(model_name=GEMINI_VISION_MODEL)
    resp = gen_model.generate_content(
        [prompt, {"mime_type": mime_type, "data": img_bytes}]
    )
    return getattr(resp, "text", "") or ""


def gemini_images(prompt: str, count: int) -> list:
    """
    Generate images through Gemini's Imagen model. Returns a list of base64
    strings. Raises RuntimeError if the installed SDK does not expose image
    generation (Imagen access varies by SDK version / account).
    """
    _ensure_gemini()
    if not hasattr(genai, "ImageGenerationModel"):
        raise RuntimeError(
            "Image generation is not available in this google-generativeai "
            "version. Use LLM_PROVIDER=openai for image generation, or upgrade "
            "the SDK / configure Vertex AI Imagen."
        )
    image_model = genai.ImageGenerationModel(GEMINI_IMAGE_MODEL)
    result = image_model.generate_images(prompt=prompt, number_of_images=count)
    out = []
    for img in getattr(result, "images", []) or []:
        data = getattr(img, "_image_bytes", None) or getattr(img, "image_bytes", None)
        if data:
            out.append(base64.b64encode(data).decode("utf-8"))
    return out


# ---------------------------------------------------------------------------
# Helper: standard error response
# ---------------------------------------------------------------------------
def error_response(message: str, status_code: int = 500, details: str = None):
    """Return a consistent JSON error response."""
    payload = {"error": message}
    if details:
        payload["details"] = details
    return jsonify(payload), status_code


def gemini_error_response(exc: Exception):
    """Map a Gemini/SDK exception to a friendly JSON error response."""
    msg = str(exc)
    low = msg.lower()
    if "api key" in low or "permission" in low or "401" in low or "403" in low:
        return error_response(f"Gemini authentication error: {msg}", 503)
    if "quota" in low or "rate" in low or "429" in low:
        return error_response("Gemini rate limit / quota exceeded. Please try again later.", 429)
    return error_response(f"Gemini API error: {msg}", 502)


# ===========================================================================
# Health Check
# ===========================================================================
@app.get("/health")
def health():
    """Simple health check endpoint — useful for uptime monitors and deploys."""
    return jsonify({
        "ok": True,
        "provider": LLM_PROVIDER,
        "models": active_models(),
    })


# ===========================================================================
# POST /v1/chat — Text Chat Completion
# ===========================================================================
@app.post("/v1/chat")
def chat():
    """
    Chat completion endpoint.

    Request JSON:
        {
            "messages": [{"role": "user", "content": "Hello"}],
            "model": "gpt-4o",           // optional, provider-specific default
            "temperature": 0.7            // optional, 0.0–2.0
        }

    Response JSON:
        {
            "reply": "AI response text",
            "usage": { ... }              // present for OpenAI; null fields for Gemini
        }
    """
    # --- Parse request ---
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])
    requested_model = data.get("model")
    temperature = data.get("temperature", 0.7)

    # --- Validate ---
    if not messages:
        return error_response("'messages' field is required and must be a non-empty array.", 400)

    if not isinstance(messages, list):
        return error_response("'messages' must be an array of message objects.", 400)

    if len(messages) > MAX_CHAT_MESSAGES:
        return error_response(
            f"Too many messages. Maximum is {MAX_CHAT_MESSAGES}.", 400
        )

    # Validate each message has role and content
    for i, msg in enumerate(messages):
        if not isinstance(msg, dict) or "role" not in msg or "content" not in msg:
            return error_response(
                f"Message at index {i} must have 'role' and 'content' fields.", 400
            )

    # Clamp temperature to valid range
    try:
        temperature = max(0.0, min(2.0, float(temperature)))
    except (ValueError, TypeError):
        temperature = 0.7

    # --- Gemini provider ---
    if LLM_PROVIDER == "gemini":
        try:
            reply = gemini_chat(messages, requested_model or GEMINI_CHAT_MODEL, temperature)
            return jsonify({
                "reply": reply,
                "usage": {"prompt_tokens": None, "completion_tokens": None, "total_tokens": None},
            })
        except RuntimeError as e:
            return error_response(str(e), 503)
        except Exception as e:
            traceback.print_exc()
            return gemini_error_response(e)

    # --- OpenAI provider (default) ---
    model = requested_model or OPENAI_CHAT_MODEL
    try:
        client = get_openai_client()
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
        )

        choice = resp.choices[0]
        reply = choice.message.content or ""
        usage = getattr(resp, "usage", None)

        return jsonify({
            "reply": reply,
            "usage": {
                "prompt_tokens": getattr(usage, "prompt_tokens", None),
                "completion_tokens": getattr(usage, "completion_tokens", None),
                "total_tokens": getattr(usage, "total_tokens", None),
            }
        })

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Please try again.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during chat completion.", 500, details=str(e))


# ===========================================================================
# POST /v1/images — Image Generation
# ===========================================================================
@app.post("/v1/images")
def images():
    """
    Image generation endpoint.

    Request JSON:
        {
            "prompt": "A cute corgi in a space suit",
            "count": 2,                    // optional, 1–4, default 2
            "size": "1024x1024",           // optional (OpenAI only)
            "response_format": "b64_json"  // accepted for compatibility
        }

    Response JSON:
        {
            "images": ["base64_encoded_string", ...]
        }
    """
    # --- Parse request ---
    data = request.get_json(force=True, silent=True) or {}
    prompt = data.get("prompt", "").strip()
    count = data.get("count", 2)
    size = data.get("size", "1024x1024")
    # Note: response_format is accepted from the client for compatibility.
    _ = data.get("response_format")

    # --- Validate ---
    if not prompt:
        return error_response("'prompt' field is required and cannot be empty.", 400)

    # Clamp count to safe range
    try:
        count = max(1, min(MAX_IMAGE_COUNT, int(count)))
    except (ValueError, TypeError):
        count = 2

    # --- Gemini provider ---
    if LLM_PROVIDER == "gemini":
        try:
            result_images = gemini_images(prompt, count)
            if not result_images:
                return error_response("Image generation succeeded but no image data was returned.", 500)
            return jsonify({"images": result_images})
        except RuntimeError as e:
            # SDK missing, key missing, or image generation unsupported.
            return error_response(str(e), 501)
        except Exception as e:
            traceback.print_exc()
            return gemini_error_response(e)

    # --- OpenAI provider (default) ---
    mapped_size = _normalize_image_size(size)
    try:
        client = get_openai_client()
        resp = client.images.generate(
            model=OPENAI_IMAGE_MODEL,
            prompt=prompt,
            n=count,
            size=mapped_size,
        )

        # Extract base64 image data from the response
        result_images = []
        for d in resp.data:
            b64 = getattr(d, "b64_json", None)
            if b64:
                result_images.append(b64)
            else:
                # Fallback: some models/configurations may return URLs
                url = getattr(d, "url", None)
                if url:
                    result_images.append(url)

        if not result_images:
            return error_response("Image generation succeeded but no image data was returned.", 500)

        return jsonify({"images": result_images})

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Image generation can take a while.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during image generation.", 500, details=str(e))


def _normalize_image_size(size_str: str) -> str:
    """
    Normalize a requested image size to one of the sizes supported by
    gpt-image-1.5: 1024x1024, 1024x1536, 1536x1024, or auto.

    If the requested size doesn't match, we map it based on aspect ratio:
        - Square -> 1024x1024
        - Landscape (wider) -> 1536x1024
        - Portrait (taller) -> 1024x1536
    """
    allowed = {"1024x1024", "1024x1536", "1536x1024", "auto"}
    if size_str in allowed:
        return size_str
    try:
        parts = size_str.lower().split("x")
        if len(parts) == 2:
            w, h = int(parts[0]), int(parts[1])
            if w <= 0 or h <= 0:
                return "1024x1024"
            if w == h:
                return "1024x1024"
            return "1536x1024" if w > h else "1024x1536"
    except (ValueError, IndexError):
        pass
    return "1024x1024"


# ===========================================================================
# POST /v1/vision — Image Analysis (Vision)
# ===========================================================================
@app.post("/v1/vision")
def vision():
    """
    Vision endpoint — analyze an image.

    Request: multipart/form-data
        - file: image binary (JPEG, PNG, etc.) — required
        - prompt: text prompt for analysis — optional, defaults to "Describe this image."

    Response JSON:
        {
            "result": "AI analysis of the image"
        }
    """
    # --- Validate file presence ---
    if "file" not in request.files:
        return error_response(
            "'file' field is required. Send an image as multipart/form-data.", 400
        )

    prompt = request.form.get("prompt", "Describe this image.").strip()
    if not prompt:
        prompt = "Describe this image."

    file = request.files["file"]

    # --- Read and validate image data ---
    img_bytes = file.read()

    if not img_bytes:
        return error_response("The uploaded file is empty.", 400)

    if len(img_bytes) > MAX_IMAGE_SIZE_BYTES:
        return error_response(
            f"Image too large. Maximum size is {MAX_IMAGE_SIZE_BYTES // 1_000_000} MB.",
            413
        )

    # Detect MIME type from file extension or default to jpeg
    filename = file.filename or "image.jpg"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
    mime_map = {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
                "gif": "image/gif", "webp": "image/webp"}
    mime_type = mime_map.get(ext, "image/jpeg")

    # --- Gemini provider ---
    if LLM_PROVIDER == "gemini":
        try:
            result = gemini_vision(prompt, img_bytes, mime_type)
            return jsonify({"result": result})
        except RuntimeError as e:
            return error_response(str(e), 503)
        except Exception as e:
            traceback.print_exc()
            return gemini_error_response(e)

    # --- OpenAI provider (default) ---
    b64 = base64.b64encode(img_bytes).decode("utf-8")
    try:
        client = get_openai_client()

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{mime_type};base64,{b64}"
                        }
                    },
                ],
            }
        ]

        resp = client.chat.completions.create(
            model=OPENAI_VISION_MODEL,
            messages=messages,
            temperature=0.2,
            max_tokens=1024,
        )

        reply = resp.choices[0].message.content or ""
        return jsonify({"result": reply})

    except RateLimitError:
        return error_response("OpenAI rate limit exceeded. Please try again later.", 429)
    except APITimeoutError:
        return error_response("OpenAI request timed out. Please try again.", 504)
    except APIConnectionError:
        return error_response("Could not connect to OpenAI. Check network or API status.", 502)
    except APIError as e:
        return error_response(f"OpenAI API error: {str(e)}", 502)
    except RuntimeError as e:
        return error_response(str(e), 503)
    except Exception as e:
        traceback.print_exc()
        return error_response("Internal server error during vision analysis.", 500, details=str(e))


# ===========================================================================
# POST /v1/chat/stream — Streaming chat (Server-Sent Events)
# ===========================================================================
@app.post("/v1/chat/stream")
def chat_stream():
    """
    Streaming chat via SSE. Emits `data: {"delta": "..."}` lines, then
    `data: [DONE]`. Works for both providers. Consumed by iOS AIProStreamClient.
    """
    data = request.get_json(force=True, silent=True) or {}
    messages = data.get("messages", [])
    requested_model = data.get("model")
    temperature = data.get("temperature", 0.7)

    if not messages:
        return error_response("'messages' field is required and must be a non-empty array.", 400)
    try:
        temperature = max(0.0, min(2.0, float(temperature)))
    except (ValueError, TypeError):
        temperature = 0.7

    def sse(obj):
        return f"data: {json.dumps(obj)}\n\n"

    def generate():
        try:
            if LLM_PROVIDER == "gemini":
                _ensure_gemini()
                system_parts = [m.get("content", "") for m in messages if m.get("role") == "system"]
                system_instruction = "\n".join(p for p in system_parts if p) or None
                contents = [
                    {"role": ("model" if m.get("role") == "assistant" else "user"), "parts": [m.get("content", "")]}
                    for m in messages if m.get("role") != "system"
                ]
                model = genai.GenerativeModel(
                    model_name=_gemini_resolve_chat_model(requested_model or GEMINI_CHAT_MODEL),
                    system_instruction=system_instruction,
                )
                for chunk in model.generate_content(
                    contents,
                    generation_config=genai.types.GenerationConfig(temperature=temperature),
                    stream=True,
                ):
                    text = getattr(chunk, "text", "") or ""
                    if text:
                        yield sse({"delta": text})
            else:
                client = get_openai_client()
                stream = client.chat.completions.create(
                    model=requested_model or OPENAI_CHAT_MODEL,
                    messages=messages,
                    temperature=temperature,
                    stream=True,
                )
                for event in stream:
                    choices = getattr(event, "choices", None)
                    if not choices:
                        continue
                    delta = getattr(choices[0].delta, "content", None) or ""
                    if delta:
                        yield sse({"delta": delta})
            yield "data: [DONE]\n\n"
        except Exception as e:
            traceback.print_exc()
            yield sse({"error": str(e)})
            yield "data: [DONE]\n\n"

    return Response(generate(), mimetype="text/event-stream")


# ===========================================================================
# Global error handlers
# ===========================================================================
@app.errorhandler(404)
def not_found(e):
    return error_response("Endpoint not found.", 404)


@app.errorhandler(405)
def method_not_allowed(e):
    return error_response("Method not allowed.", 405)


@app.errorhandler(413)
def payload_too_large(e):
    return error_response("Request payload too large.", 413)


@app.errorhandler(500)
def internal_error(e):
    return error_response("Internal server error.", 500)


# ===========================================================================
# Run the server
# ===========================================================================
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    debug = os.environ.get("FLASK_DEBUG", "true").lower() in ("true", "1", "yes")

    models = active_models()
    print(f"Starting TheSwiftKit AI Backend on port {port}")
    print(f"  Provider:     {LLM_PROVIDER}")
    print(f"  Chat model:   {models['chat']}")
    print(f"  Image model:  {models['image']}")
    print(f"  Vision model: {models['vision']}")
    print(f"  Debug mode:   {debug}")

    app.run(host="0.0.0.0", port=port, debug=debug)
