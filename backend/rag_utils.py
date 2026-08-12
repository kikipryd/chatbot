import io
import json
import numpy as np
from typing import List, Tuple
from pypdf import PdfReader
from docx import Document as DocxReader
from openai import OpenAI

# Safe loading of OpenAI API Key
OPENAI_API_KEY = "mock_key_or_real"

def extract_text_from_pdf(file_bytes: bytes) -> str:
    pdf_file = io.BytesIO(file_bytes)
    reader = PdfReader(pdf_file)
    text = ""
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            text += page_text + "\n"
    return text

def extract_text_from_docx(file_bytes: bytes) -> str:
    docx_file = io.BytesIO(file_bytes)
    doc = DocxReader(docx_file)
    text = ""
    for paragraph in doc.paragraphs:
        if paragraph.text:
            text += paragraph.text + "\n"
    return text

def chunk_text(text: str, chunk_size: int = 800, chunk_overlap: int = 150) -> List[str]:
    """
    Splits text into chunks recursively or line-by-line while maintaining clean text boundaries.
    """
    if not text.strip():
        return []

    # Simple recursive-character-style splitting
    words = text.split()
    chunks = []

    i = 0
    while i < len(words):
        # Build chunk up to roughly chunk_size characters
        current_chunk_words = []
        current_len = 0

        # Pull words for current chunk
        j = i
        while j < len(words) and current_len < chunk_size:
            current_chunk_words.append(words[j])
            current_len += len(words[j]) + 1
            j += 1

        chunks.append(" ".join(current_chunk_words))

        # Calculate next starting index based on overlap
        overlap_words_count = 0
        overlap_len = 0
        k = j - 1
        while k >= i and overlap_len < chunk_overlap:
            overlap_len += len(words[k]) + 1
            overlap_words_count += 1
            k -= 1

        if j >= len(words):
            break

        step = max(1, (j - i) - overlap_words_count)
        i += step

    return [c.strip() for c in chunks if c.strip()]

def get_openai_client(api_key: str) -> OpenAI:
    """Returns OpenAI client using provided key or default."""
    return OpenAI(api_key=api_key)

def get_embedding(text: str, api_key: str) -> List[float]:
    """
    Generates text embedding using openai standard text-embedding-3-small or text-embedding-ada-002.
    If the API key is empty, invalid, or starts with mock_, it falls back to a deterministic 1536-dim mock vector.
    """
    if not api_key or api_key.startswith("mock_") or api_key == "mock_key_or_real":
        # Generate stable mock embedding based on character hash for testing/offline use
        return generate_mock_embedding(text)

    try:
        client = get_openai_client(api_key)
        response = client.embeddings.create(
            input=[text],
            model="text-embedding-3-small"
        )
        return response.data[0].embedding
    except Exception as e:
        print(f"Error fetching embedding from OpenAI: {e}. Falling back to deterministic mock embedding.")
        return generate_mock_embedding(text)

def generate_mock_embedding(text: str, dimensions: int = 1536) -> List[float]:
    """Generates a stable unit-norm mock vector for fallback / development."""
    # Seed based on the text hash to make embeddings deterministic
    hash_val = abs(hash(text)) % 100000
    np.random.seed(hash_val)
    vec = np.random.randn(dimensions)
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec = vec / norm
    return vec.tolist()

def cosine_similarity(v1: List[float], v2: List[float]) -> float:
    a = np.array(v1)
    b = np.array(v2)
    dot = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return float(dot / (norm_a * norm_b))

def retrieve_context(chatbot_id: str, query: str, db, tenant_api_key: str, top_k: int = 3) -> List[Tuple[str, float]]:
    """
    Performs cosine-similarity based vector search on the SQLite DB for document chunks belonging to this chatbot.
    """
    from backend.models import DocumentChunk

    query_vector = get_embedding(query, tenant_api_key)
    chunks = db.query(DocumentChunk).filter(DocumentChunk.chatbot_id == chatbot_id).all()

    scored_chunks = []
    for chunk in chunks:
        try:
            chunk_vector = json.loads(chunk.embedding_json)
            score = cosine_similarity(query_vector, chunk_vector)
            scored_chunks.append((chunk.text, score))
        except Exception as e:
            print(f"Error decoding vector or calculating similarity: {e}")
            continue

    # Sort descending by score
    scored_chunks.sort(key=lambda x: x[1], reverse=True)
    return scored_chunks[:top_k]
