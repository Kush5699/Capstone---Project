from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import google.genai.types as types
from google.adk import Runner
from agents.common import get_session_service
from agents.orchestrator import create_orchestrator_agent
from agents.mentor import create_mentor_agent
from agents.manager import create_manager_agent
from agents.reviewer import create_reviewer_agent
from agents.executor import create_executor_agent
from agents.advisor import create_advisor_agent
from models import AgentRequest, AgentResponse, Topic, Task
import traceback
import uuid
import subprocess
import sys
from pydantic import BaseModel
from tools import execute_python_code

class ExecutionRequest(BaseModel):
    code: str
    language: str = "python"

class ExecutionResponse(BaseModel):
    output: str
    error: str

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Agents
try:
    orchestrator_agent = create_orchestrator_agent()
    mentor_agent = create_mentor_agent()
    manager_agent = create_manager_agent()
    reviewer_agent = create_reviewer_agent()
    executor_agent = create_executor_agent()
    advisor_agent = create_advisor_agent()
    session_service = get_session_service()
    print("Agents and Services initialized successfully.")
except Exception as e:
    print(f"Error initializing agents: {e}")

# In-memory storage for topics
TOPICS = {
    "default": "General Chat"
}

# In-memory storage for history: {topic_id: [{"role": str, "content": str}]}
HISTORY = {}

# In-memory storage for tasks: {task_id: Task}
TASKS = {}

@app.get("/")
def read_root():
    return {"message": "CareerForge AI Backend is running with Google ADK"}

@app.get("/topics", response_model=list[Topic])
def get_topics():
    return [Topic(id=k, title=v) for k, v in TOPICS.items()]

@app.post("/topics", response_model=Topic)
def create_topic(title: str):
    topic_id = str(uuid.uuid4())
    TOPICS[topic_id] = title
    return Topic(id=topic_id, title=title)

@app.delete("/topics/{topic_id}")
def delete_topic(topic_id: str):
    if topic_id in TOPICS:
        del TOPICS[topic_id]
    if topic_id in HISTORY:
        del HISTORY[topic_id]
    return {"message": "Topic deleted"}

@app.get("/history/{topic_id}")
async def get_history(topic_id: str):
    return HISTORY.get(topic_id, [])

@app.post("/tasks/generate", response_model=Task)
async def generate_task(topic_id: str):
    try:
        # 1. Gather Context
        topic_title = TOPICS.get(topic_id, "General")
        history = HISTORY.get(topic_id, [])
        
        # Extract learning summary from history (naive approach: just dump last N messages)
        # A better approach would be to ask an agent to summarize, but for speed we'll just pass recent history.
        context_text = f"Topic: {topic_title}\nChat History:\n"
        for msg in history[-10:]: # Last 10 messages
            context_text += f"{msg['role']}: {msg['content']}\n"
            
        # 2. Check previous tasks to avoid repetition
        previous_tasks = [t for t in TASKS.values() if t.topic_id == topic_id]
        if previous_tasks:
            context_text += "\nPrevious Tasks:\n"
            for t in previous_tasks:
                context_text += f"- {t.title}: {t.description}\n"
                
        # 3. Prompt Manager Agent
        prompt = f"""
        Based on the following learning context, generate a new, unique coding task for the user.
        The task should be relevant to what they have recently discussed or learned.
        Do not repeat previous tasks.
        
        {context_text}
        
        Format the output exactly as:
        Title: [Task Title]
        Description: [Task Description]
        """
        
        # We use the Manager agent directly
        # Note: We need a session for the manager runner, we can reuse the topic_id as session
        session_id = f"session_{topic_id}"
        
        # Ensure session exists
        try:
            await session_service.create_session(session_id=session_id, app_name="CareerForge", user_id="user_1")
        except Exception:
            # Likely already exists
            pass
        
        # We need to run the manager. 
        # Since we are calling it programmatically, we can use the Runner.
        # But wait, the Runner expects a user message.
        # We can simulate a user message asking for a task with context.
        
        user_message = types.Content(role="user", parts=[types.Part(text=prompt)])
        runner = Runner(agent=manager_agent, session_service=session_service, app_name="CareerForge")
        
        response_text = ""
        async for chunk in runner.run_async(user_id="user_1", session_id=session_id, new_message=user_message):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text
                        
        # 4. Parse Response (Simple parsing)
        title = "New Task"
        description = response_text
        
        # Try to parse Title/Description if formatted
        lines = response_text.strip().split('\n')
        for line in lines:
            if line.startswith("Title:"):
                title = line.replace("Title:", "").strip()
            elif line.startswith("Description:"):
                # This might be the start of description, or the whole description follows
                pass
                
        # If description is just the whole text, that's fine too for now.
        # Let's clean it up a bit if we found a title.
        if title != "New Task":
            description = response_text.replace(f"Title: {title}", "").replace("Description:", "").strip()

        # 5. Create Task
        task_id = str(uuid.uuid4())
        new_task = Task(
            id=task_id,
            topic_id=topic_id,
            title=title,
            description=description
        )
        TASKS[task_id] = new_task
        return new_task
    except Exception as e:
        traceback.print_exc()
        print(f"Error generating task: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks")
def get_tasks(topic_id: str = None):
    if topic_id:
        return [t for t in TASKS.values() if t.topic_id == topic_id]
    return list(TASKS.values())

@app.put("/tasks/{task_id}", response_model=Task)
def update_task(task_id: str, task_update: Task):
    if task_id in TASKS:
        # Update fields
        current_task = TASKS[task_id]
        current_task.status = task_update.status
        current_task.code = task_update.code
        current_task.feedback = task_update.feedback
        TASKS[task_id] = current_task
        return current_task
    raise HTTPException(status_code=404, detail="Task not found")

@app.post("/execute", response_model=ExecutionResponse)
def execute_code(request: ExecutionRequest):
    if request.language.lower() != "python":
        return ExecutionResponse(output="", error="Only Python is supported for now.")
    
    try:
        # Run code using the shared tool function
        output = execute_python_code(request.code)
        
        # Parse output to separate stdout and error if possible, 
        # but our tool returns a combined string.
        # For this API, we can just put it all in output or try to split.
        # The tool returns "Error: ..." if there's an error.
        
        if output.startswith("Error:"):
             return ExecutionResponse(output="", error=output)
        else:
             return ExecutionResponse(output=output, error="")
             
    except Exception as e:
        return ExecutionResponse(output="", error=str(e))

@app.post("/chat", response_model=AgentResponse)
async def chat_endpoint(request: AgentRequest):
    try:
        user_id = "user_1" # Fixed user for MVP
        
        # Use topic_id as session_id if provided, otherwise default
        topic_id = request.topic_id if request.topic_id else "default"
        session_id = f"session_{topic_id}"
        
        # Ensure topic exists in our dict (if passed from client but not in dict, maybe add it?)
        if topic_id not in TOPICS:
            TOPICS[topic_id] = "Unknown Topic"
            
        # Initialize history for topic if needed
        if topic_id not in HISTORY:
            HISTORY[topic_id] = []
        
        # Add User Message to History
        HISTORY[topic_id].append({"role": "user", "content": request.message})
        
        # Ensure session exists
        # InMemorySessionService doesn't throw if exists, but let's be safe or just create.
        # Since it's in-memory, it resets on restart anyway.
        # We can try to create it every time or check.
        # For simplicity/robustness in MVP, we just try to create and catch error if it complains about existence,
        # but InMemory might overwrite or just work.
        # Actually, debug script showed it failed if NOT exists.
        # Let's try to get it, if fails, create it.
        # But InMemorySessionService might not have get_session exposed easily or it's async.
        # Let's just try to create it and ignore "already exists" if that's an error, 
        # OR just create it once at startup? No, user might be dynamic.
        # Let's just await create_session and wrap in try-except.
        try:
            await session_service.create_session(session_id=session_id, app_name="CareerForge", user_id=user_id)
        except Exception:
            # Likely already exists
            pass

        # 1. Orchestrator decides who handles it
        orchestrator_runner = Runner(agent=orchestrator_agent, session_service=session_service, app_name="CareerForge")
        routing_decision = ""
        
        # Wrap message
        user_message = types.Content(role="user", parts=[types.Part(text=request.message)])
        
        async for chunk in orchestrator_runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            # The chunk might be an Event object, we need to extract text.
            # In debug output: model_version='...' content=Content(...)
            # We need to parse the event.
            # Actually, the chunk printed in debug was an Event object.
            # We need to check if it has content.
            # Let's inspect the chunk structure in the loop.
            # For now, let's assume str(chunk) or chunk.content.parts[0].text
            # Wait, the debug output showed:
            # model_version='...' content=Content(parts=[Part(text="MENTOR\n")], ...)
            # So chunk.content.parts[0].text is the way.
            if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        routing_decision += part.text
        
        target_agent_name = routing_decision.strip().upper()
        print(f"Routing to: {target_agent_name}")

        target_agent = None
        if "MENTOR" in target_agent_name:
            target_agent = mentor_agent
            target_agent_name = "MENTOR"
        elif "MANAGER" in target_agent_name:
            target_agent = manager_agent
            target_agent_name = "MANAGER"
        elif "REVIEWER" in target_agent_name:
            target_agent = reviewer_agent
            target_agent_name = "REVIEWER"
        elif "EXECUTOR" in target_agent_name:
            target_agent = executor_agent
            target_agent_name = "EXECUTOR"
        elif "ADVISOR" in target_agent_name:
            target_agent = advisor_agent
            target_agent_name = "ADVISOR"
        else:
            # Default fallback
            target_agent = mentor_agent
            target_agent_name = "MENTOR"

        # 2. Run the target agent
        runner = Runner(agent=target_agent, session_service=session_service, app_name="CareerForge")
        response_text = ""
        
        # We need to send the message again to the target agent?
        # Or does the session keep state?
        # The session keeps state! So we don't need to send the message again?
        # Wait, the Orchestrator consumed the message.
        # If we want the Mentor to reply to the *same* message, we might need to re-send it or just send a "proceed" signal?
        # Actually, usually Orchestrator is a router.
        # In this simple design, we sent the user message to Orchestrator.
        # Now we want the Mentor to answer *that* message.
        # But the Mentor wasn't part of that turn.
        # We should probably send the user message to the Mentor directly.
        # But the session history now has User: Msg -> Orchestrator: MENTOR.
        # If we send User: Msg to Mentor, the history will be User: Msg -> Orchestrator: MENTOR -> User: Msg -> Mentor: Response.
        # That's fine.
        
        async for chunk in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text

        # Add Agent Response to History
        HISTORY[topic_id].append({"role": "agent", "content": response_text})

        return AgentResponse(response=response_text, agent_type=target_agent_name)

    except Exception as e:
        traceback.print_exc()
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
