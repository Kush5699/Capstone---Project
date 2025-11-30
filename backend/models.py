from pydantic import BaseModel
from typing import List, Optional

class ChatMessage(BaseModel):
    role: str
    content: str

class AgentRequest(BaseModel):
    user_id: str
    message: str
    topic_id: Optional[str] = None
    history: List[ChatMessage] = []

class AgentResponse(BaseModel):
    response: str
    agent_type: str

class Topic(BaseModel):
    id: str
    title: str

class Task(BaseModel):
    id: str
    topic_id: str
    title: str
    description: str
    status: str = "Pending" # Pending, Completed
    code: str = ""
    feedback: str = ""
