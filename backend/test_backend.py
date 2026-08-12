import unittest
import json
from sqlalchemy.orm import Session
from backend.models import SessionLocal, Tenant, Chatbot, Document, DocumentChunk, init_db, get_password_hash
from backend.rag_utils import chunk_text, generate_mock_embedding, cosine_similarity

class TestBackendLogic(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        cls.db: Session = SessionLocal()

    @classmethod
    def tearDownClass(cls):
        cls.db.close()

    def test_chunking_logic(self):
        sample_text = "Ini adalah teks tes panjang yang akan diuji untuk pemecahan teks menjadi potongan-potongan kecil. Teks ini sengaja dibuat agar bisa diuji dengan baik dan benar dalam fungsionalitas RAG."
        chunks = chunk_text(sample_text, chunk_size=50, chunk_overlap=10)
        self.assertTrue(len(chunks) > 0)
        for chunk in chunks:
            self.assertTrue(len(chunk) > 0)

    def test_mock_embeddings_and_cosine_similarity(self):
        text_a = "Sistem SaaS cerdas"
        text_b = "Sistem SaaS cerdas"
        text_c = "Sesuatu yang sangat berbeda sama sekali"

        emb_a = generate_mock_embedding(text_a)
        emb_b = generate_mock_embedding(text_b)
        emb_c = generate_mock_embedding(text_c)

        sim_same = cosine_similarity(emb_a, emb_b)
        sim_diff = cosine_similarity(emb_a, emb_c)

        self.assertAlmostEqual(sim_same, 1.0, places=4)
        self.assertTrue(sim_diff < 0.99) # different text should have lesser similarity

    def test_database_persistence(self):
        # Create unique tenant
        import uuid
        email = f"test_{uuid.uuid4().hex}@domain.com"
        tenant = Tenant(
            name="Test Tenant",
            email=email,
            password_hash=get_password_hash("password123"),
            tier="Free"
        )
        self.db.add(tenant)
        self.db.commit()

        # Fetch tenant
        db_tenant = self.db.query(Tenant).filter(Tenant.email == email).first()
        self.assertIsNotNone(db_tenant)
        self.assertEqual(db_tenant.name, "Test Tenant")

        # Cleanup
        self.db.delete(db_tenant)
        self.db.commit()

if __name__ == "__main__":
    unittest.main()
