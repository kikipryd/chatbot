import os
import math
import uuid
import bcrypt
from typing import List, Optional
from datetime import datetime
from sqlalchemy import (
    create_engine, Column, String, Integer, Float, Text, ForeignKey, DateTime, Boolean
)
from sqlalchemy.orm import declarative_base, sessionmaker, relationship

# Database configuration
DATABASE_URL = "sqlite:///./backend/saas_chatbot.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Tenant(Base):
    __tablename__ = "tenants"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    api_key = Column(String, unique=True, default=lambda: f"sk_saas_{uuid.uuid4().hex}")
    openai_api_key_override = Column(String, nullable=True) # Optional override
    tier = Column(String, default="Free") # Free, Pro, Enterprise
    created_at = Column(DateTime, default=datetime.utcnow)

    chatbots = relationship("Chatbot", back_populates="tenant", cascade="all, delete-orphan")

class Chatbot(Base):
    __tablename__ = "chatbots"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    tenant_id = Column(String, ForeignKey("tenants.id"), nullable=False)
    name = Column(String, nullable=False)
    system_prompt = Column(Text, default="You are a helpful and intelligent AI chatbot. Use the provided context to answer questions truthfully.")
    created_at = Column(DateTime, default=datetime.utcnow)

    tenant = relationship("Tenant", back_populates="chatbots")
    documents = relationship("Document", back_populates="chatbot", cascade="all, delete-orphan")
    sessions = relationship("ChatSession", back_populates="chatbot", cascade="all, delete-orphan")

class Document(Base):
    __tablename__ = "documents"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    chatbot_id = Column(String, ForeignKey("chatbots.id"), nullable=False)
    filename = Column(String, nullable=False)
    file_type = Column(String, nullable=False) # PDF or DOCX
    created_at = Column(DateTime, default=datetime.utcnow)

    chatbot = relationship("Chatbot", back_populates="documents")
    chunks = relationship("DocumentChunk", back_populates="document", cascade="all, delete-orphan")

class DocumentChunk(Base):
    __tablename__ = "document_chunks"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    document_id = Column(String, ForeignKey("documents.id"), nullable=False)
    chatbot_id = Column(String, nullable=False) # Copied for quick vector query filtering
    text = Column(Text, nullable=False)
    # Store embedding as serialised JSON float array
    embedding_json = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    document = relationship("Document", back_populates="chunks")

class ChatSession(Base):
    __tablename__ = "chat_sessions"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    chatbot_id = Column(String, ForeignKey("chatbots.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    chatbot = relationship("Chatbot", back_populates="sessions")
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan")

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, ForeignKey("chat_sessions.id"), nullable=False)
    role = Column(String, nullable=False) # "user" or "assistant"
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("ChatSession", back_populates="messages")


# Helper methods for Tenant Auth using pure bcrypt
def get_password_hash(password: str) -> str:
    pwd_bytes = password.encode('utf-8')
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(pwd_bytes, salt)
    return hashed.decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
