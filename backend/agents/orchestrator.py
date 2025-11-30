from google.adk import Agent
from .common import get_model

def create_orchestrator_agent():
    prompt = """
    You are the Orchestrator. Route the user to the right agent:
    - Learning/Questions -> MENTOR
    - Asking for Task -> MANAGER
    - Submitting Code -> REVIEWER
    - Running/Executing Code -> EXECUTOR
    - Suggestions/Help -> ADVISOR
    
    Return ONLY the agent name (MENTOR, MANAGER, REVIEWER, EXECUTOR, or ADVISOR).
    """
    return Agent(model=get_model(), name="Orchestrator", instruction=prompt)
