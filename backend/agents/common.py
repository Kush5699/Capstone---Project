import os
from dotenv import load_dotenv
from google.adk.models import Gemini
from google.adk.sessions import InMemorySessionService

load_dotenv()

_model = None
_session_service = None

def get_model():
    global _model
    if not _model:
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            raise ValueError("GOOGLE_API_KEY not found")
        _model = Gemini(model="gemini-2.0-flash", api_key=api_key)
    return _model

def get_session_service():
    global _session_service
    if not _session_service:
        _session_service = InMemorySessionService()
    return _session_service
