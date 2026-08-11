import os
import json
from fastapi import FastAPI, Depends, Request, Form, HTTPException, File, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from starlette.middleware.sessions import SessionMiddleware

from backend.models import (
    init_db, get_db, Tenant, Chatbot, Document, DocumentChunk,
    get_password_hash, verify_password
)
from backend.rag_utils import (
    extract_text_from_pdf, extract_text_from_docx, chunk_text, get_embedding
)
from backend.api import router as api_router

# Initialize FastAPI application
app = FastAPI(title="SaaS AI Chatbot Platform")

# CORS and Session Support
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(SessionMiddleware, secret_key="saas_secret_super_key_random")

# Ensure templates directory exists and setup Jinja2
templates = Jinja2Templates(directory="backend/templates")

# Initialize SQLite database schema
init_db()

# Mount API Router
app.include_router(api_router, prefix="/api")

# Helper to retrieve active session tenant
def get_session_tenant(request: Request, db: Session) -> Tenant:
    tenant_id = request.session.get("tenant_id")
    if not tenant_id:
        return None
    return db.query(Tenant).filter(Tenant.id == tenant_id).first()

# ----------------- WEB WEB ROUTING -----------------

@app.get("/", response_class=HTMLResponse)
def index_page(request: Request, bot_id: str = None, db: Session = Depends(get_db)):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    chatbots = db.query(Chatbot).filter(Chatbot.tenant_id == tenant.id).all()
    selected_bot = None
    if bot_id:
        selected_bot = db.query(Chatbot).filter(Chatbot.id == bot_id, Chatbot.tenant_id == tenant.id).first()
    elif chatbots:
        selected_bot = chatbots[0]

    return templates.TemplateResponse("index.html", {
        "request": request,
        "tenant": tenant,
        "chatbots": chatbots,
        "selected_bot": selected_bot
    })

@app.get("/login", response_class=HTMLResponse)
def login_page(request: Request):
    return templates.TemplateResponse("login.html", {"request": request, "error": None})

@app.post("/login", response_class=HTMLResponse)
def handle_login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    tenant = db.query(Tenant).filter(Tenant.email == email).first()
    if not tenant or not verify_password(password, tenant.password_hash):
        return templates.TemplateResponse("login.html", {
            "request": request, "error": "Email atau password yang Anda masukkan salah."
        })

    request.session["tenant_id"] = tenant.id
    return RedirectResponse(url="/", status_code=303)

@app.get("/register", response_class=HTMLResponse)
def register_page(request: Request):
    return templates.TemplateResponse("register.html", {"request": request, "error": None})

@app.post("/register", response_class=HTMLResponse)
def handle_register(
    request: Request,
    name: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    tier: str = Form(...),
    db: Session = Depends(get_db)
):
    # Check if tenant email exists
    existing = db.query(Tenant).filter(Tenant.email == email).first()
    if existing:
        return templates.TemplateResponse("register.html", {
            "request": request, "error": "Email sudah terdaftar di platform kami."
        })

    new_tenant = Tenant(
        name=name,
        email=email,
        password_hash=get_password_hash(password),
        tier=tier
    )
    db.add(new_tenant)
    db.commit()
    db.refresh(new_tenant)

    # Auto login after register
    request.session["tenant_id"] = new_tenant.id
    return RedirectResponse(url="/", status_code=303)

@app.get("/logout")
def handle_logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/login", status_code=303)

# ----------------- CHATBOT MANAGEMENT ACTIONS -----------------

@app.post("/create-chatbot")
def handle_create_chatbot(
    request: Request,
    name: str = Form(...),
    system_prompt: str = Form(...),
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    # Check SaaS limitations based on Subscription Tiers
    current_bots_count = db.query(Chatbot).filter(Chatbot.tenant_id == tenant.id).count()
    if tenant.tier == "Free" and current_bots_count >= 1:
        return HTMLResponse("Batas Maksimal Paket FREE Terlampaui! Upgrade ke PRO untuk membuat lebih banyak Chatbot.")
    elif tenant.tier == "Pro" and current_bots_count >= 5:
        return HTMLResponse("Batas Maksimal Paket PRO Terlampaui! Hubungi tim sales untuk Enterprise.")

    bot = Chatbot(
        tenant_id=tenant.id,
        name=name,
        system_prompt=system_prompt
    )
    db.add(bot)
    db.commit()
    return RedirectResponse(url=f"/?bot_id={bot.id}", status_code=303)

@app.get("/delete-chatbot")
def handle_delete_chatbot(
    request: Request,
    bot_id: str,
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    bot = db.query(Chatbot).filter(Chatbot.id == bot_id, Chatbot.tenant_id == tenant.id).first()
    if bot:
        db.delete(bot)
        db.commit()
    return RedirectResponse(url="/", status_code=303)

@app.post("/update-prompt")
def handle_update_prompt(
    request: Request,
    bot_id: str = Form(...),
    name: str = Form(...),
    system_prompt: str = Form(...),
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    bot = db.query(Chatbot).filter(Chatbot.id == bot_id, Chatbot.tenant_id == tenant.id).first()
    if bot:
        bot.name = name
        bot.system_prompt = system_prompt
        db.commit()
    return RedirectResponse(url=f"/?bot_id={bot.id}", status_code=303)

@app.post("/save-openai-override")
def handle_openai_override(
    request: Request,
    openai_key: str = Form(...),
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    tenant.openai_api_key_override = openai_key.strip() or None
    db.commit()
    return RedirectResponse(url="/", status_code=303)

# ----------------- DATA SOURCE / FILE UPLOAD & PARSING -----------------

@app.post("/upload-document")
async def handle_upload_document(
    request: Request,
    bot_id: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    bot = db.query(Chatbot).filter(Chatbot.id == bot_id, Chatbot.tenant_id == tenant.id).first()
    if not bot:
        raise HTTPException(status_code=404, detail="Chatbot not found")

    # Subscription limit check for documents count
    current_docs_count = db.query(Document).filter(Document.chatbot_id == bot.id).count()
    if tenant.tier == "Free" and current_docs_count >= 3:
        return HTMLResponse("Batas Maksimal Dokumen Terlampaui untuk Paket FREE! Silakan upgrade paket.")
    elif tenant.tier == "Pro" and current_docs_count >= 20:
        return HTMLResponse("Batas Maksimal Dokumen Terlampaui untuk Paket PRO! Silakan hubungi admin.")

    filename = file.filename
    file_bytes = await file.read()

    # Process text extraction depending on file type
    text = ""
    file_type = ""
    if filename.endswith(".pdf"):
        file_type = "pdf"
        text = extract_text_from_pdf(file_bytes)
    elif filename.endswith(".docx"):
        file_type = "docx"
        text = extract_text_from_docx(file_bytes)
    else:
        return HTMLResponse("Format file tidak didukung! Hanya mendukung PDF dan DOCX.")

    if not text.strip():
        return HTMLResponse("Error: Tidak ada teks yang dapat diekstrak dari file yang diupload.")

    # Save document asset record
    doc_record = Document(
        chatbot_id=bot.id,
        filename=filename,
        file_type=file_type
    )
    db.add(doc_record)
    db.commit()
    db.refresh(doc_record)

    # Chunking & Embedding Generation
    chunks = chunk_text(text)
    api_key_to_use = tenant.openai_api_key_override or os.getenv("OPENAI_API_KEY", "mock_key_or_real")

    for idx, chunk in enumerate(chunks):
        embedding_list = get_embedding(chunk, api_key_to_use)

        chunk_model = DocumentChunk(
            document_id=doc_record.id,
            chatbot_id=bot.id,
            text=chunk,
            embedding_json=json.dumps(embedding_list)
        )
        db.add(chunk_model)

    db.commit()
    return RedirectResponse(url=f"/?bot_id={bot.id}", status_code=303)

@app.get("/delete-document")
def handle_delete_document(
    request: Request,
    doc_id: str,
    bot_id: str,
    db: Session = Depends(get_db)
):
    tenant = get_session_tenant(request, db)
    if not tenant:
        return RedirectResponse(url="/login", status_code=303)

    doc = db.query(Document).filter(Document.id == doc_id, Document.chatbot_id == bot_id).first()
    if doc:
        db.delete(doc)
        db.commit()
    return RedirectResponse(url=f"/?bot_id={bot_id}", status_code=303)
