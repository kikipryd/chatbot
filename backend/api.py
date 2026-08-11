import os
import json
from typing import Generator, Optional
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Header, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.models import get_db, Tenant, Chatbot, Document, DocumentChunk, ChatSession, ChatMessage
from backend.rag_utils import (
    extract_text_from_pdf, extract_text_from_docx, chunk_text, get_embedding, retrieve_context, get_openai_client
)

router = APIRouter()

# Schema definitions
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None

class SessionCreate(BaseModel):
    chatbot_id: str

def get_tenant_by_api_key(api_key: str, db: Session) -> Tenant:
    if not api_key:
        raise HTTPException(status_code=401, detail="API Key is missing")
    # Supports "Bearer sk_saas_..." or plain key
    clean_key = api_key.replace("Bearer ", "").strip()
    tenant = db.query(Tenant).filter(Tenant.api_key == clean_key).first()
    if not tenant:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return tenant

# ----------------- CLIENT / SDK APIS -----------------

@router.get("/v1/chatbots/info")
def get_chatbot_info(
    chatbot_id: str,
    authorization: str = Header(..., alias="Authorization"),
    db: Session = Depends(get_db)
):
    tenant = get_tenant_by_api_key(authorization, db)
    # Check if chatbot belongs to tenant
    chatbot = db.query(Chatbot).filter(Chatbot.id == chatbot_id, Chatbot.tenant_id == tenant.id).first()
    if not chatbot:
        raise HTTPException(status_code=404, detail="Chatbot not found or does not belong to tenant")
    return {
        "id": chatbot.id,
        "name": chatbot.name,
        "system_prompt": chatbot.system_prompt,
        "created_at": chatbot.created_at
    }

@router.post("/v1/sessions")
def create_chat_session(
    body: SessionCreate,
    authorization: str = Header(..., alias="Authorization"),
    db: Session = Depends(get_db)
):
    tenant = get_tenant_by_api_key(authorization, db)
    chatbot = db.query(Chatbot).filter(Chatbot.id == body.chatbot_id, Chatbot.tenant_id == tenant.id).first()
    if not chatbot:
        raise HTTPException(status_code=404, detail="Chatbot not found")

    session = ChatSession(chatbot_id=chatbot.id)
    db.add(session)
    db.commit()
    db.refresh(session)
    return {"session_id": session.id, "chatbot_id": chatbot.id}

@router.get("/v1/sessions/{session_id}/messages")
def get_session_messages(
    session_id: str,
    authorization: str = Header(..., alias="Authorization"),
    db: Session = Depends(get_db)
):
    tenant = get_tenant_by_api_key(authorization, db)
    session = db.query(ChatSession).filter(ChatSession.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Check ownership
    chatbot = db.query(Chatbot).filter(Chatbot.id == session.chatbot_id, Chatbot.tenant_id == tenant.id).first()
    if not chatbot:
        raise HTTPException(status_code=403, detail="Unauthorized session access")

    messages = db.query(ChatMessage).filter(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc()).all()
    return [{"role": m.role, "content": m.content, "created_at": m.created_at} for m in messages]

@router.post("/v1/chatbots/{chatbot_id}/chat")
def chatbot_chat_stream(
    chatbot_id: str,
    body: ChatRequest,
    authorization: str = Header(..., alias="Authorization"),
    db: Session = Depends(get_db)
):
    tenant = get_tenant_by_api_key(authorization, db)
    chatbot = db.query(Chatbot).filter(Chatbot.id == chatbot_id, Chatbot.tenant_id == tenant.id).first()
    if not chatbot:
        raise HTTPException(status_code=404, detail="Chatbot not found")

    # Verify or create session
    session_id = body.session_id
    if not session_id:
        session = ChatSession(chatbot_id=chatbot.id)
        db.add(session)
        db.commit()
        db.refresh(session)
        session_id = session.id
    else:
        session = db.query(ChatSession).filter(ChatSession.id == session_id).first()
        if not session or session.chatbot_id != chatbot.id:
            raise HTTPException(status_code=404, detail="Invalid session ID")

    # Save User message
    user_msg = ChatMessage(session_id=session_id, role="user", content=body.message)
    db.add(user_msg)
    db.commit()

    # Determine OpenAI Key to use
    api_key_to_use = tenant.openai_api_key_override or os.getenv("OPENAI_API_KEY", "mock_key_or_real")

    # Fetch context from Vector database (RAG)
    retrieved = retrieve_context(chatbot.id, body.message, db, api_key_to_use, top_k=3)
    context_str = "\n---\n".join([item[0] for item in retrieved])

    # Get conversation history
    history = db.query(ChatMessage).filter(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc()).all()

    messages_payload = [
        {"role": "system", "content": f"{chatbot.system_prompt}\n\nRELEVANT CONTEXT TO ANSWER USER QUESTION:\n{context_str}"}
    ]
    # Add historical conversation (limit to last 10 messages for efficiency)
    for h in history[-11:-1]: # exclude the latest user_msg because we add it next
        messages_payload.append({"role": h.role, "content": h.content})

    messages_payload.append({"role": "user", "content": body.message})

    # SSE Generator function
    def sse_stream_generator() -> Generator[str, None, None]:
        full_response = ""
        # Send session ID first
        yield f"data: {json.dumps({'session_id': session_id})}\n\n"

        # Check if OpenAI Key is real or mock
        if not api_key_to_use or api_key_to_use.startswith("mock_") or api_key_to_use == "mock_key_or_real":
            # Simulate a beautiful RAG answer for local/development testing
            import time
            simulated_paragraphs = [
                f"[SaaS Chatbot AI - RAG Mode Enabled]\n",
                f"Berdasarkan dokumen yang diunggah, berikut jawaban atas pertanyaan Anda: '{body.message}'\n\n",
                f"Konteks relevan ditemukan ({len(retrieved)} chunk): \n"
            ]
            for idx, (text, score) in enumerate(retrieved):
                simulated_paragraphs.append(f"- Chunk {idx+1} (Relevance {score:.2f}): \"{text[:120]}...\"\n")

            if not retrieved:
                simulated_paragraphs.append("Maaf, tidak ada dokumen sumber yang cocok ditemukan di database. Saya menjawab menggunakan pengetahuan umum.\n")

            simulated_text = "".join(simulated_paragraphs)

            # Send word-by-word with delay
            for word in simulated_text.split(" "):
                full_response += word + " "
                yield f"data: {json.dumps({'chunk': word + ' '})}\n\n"
                time.sleep(0.08)

            yield "data: [DONE]\n\n"
        else:
            try:
                client = get_openai_client(api_key_to_use)
                stream = client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=messages_payload,
                    stream=True
                )
                for chunk in stream:
                    delta = chunk.choices[0].delta.content
                    if delta:
                        full_response += delta
                        yield f"data: {json.dumps({'chunk': delta})}\n\n"

                yield "data: [DONE]\n\n"
            except Exception as e:
                error_msg = f"\n[Error communicating with OpenAI: {str(e)}]"
                yield f"data: {json.dumps({'chunk': error_msg})}\n\n"
                yield "data: [DONE]\n\n"
                full_response += error_msg

        # Save complete assistant message to db
        db_sess = get_db().__next__() # Get fresh session to ensure thread safety
        assistant_msg = ChatMessage(session_id=session_id, role="assistant", content=full_response)
        db_sess.add(assistant_msg)
        db_sess.commit()
        db_sess.close()

    return StreamingResponse(sse_stream_generator(), media_type="text/event-stream")
