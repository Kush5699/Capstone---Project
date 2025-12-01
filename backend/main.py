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
from memory_bank import MemoryBank
from logger import AgentLogger

class ExecutionRequest(BaseModel):
    code: str
    language: str = "python"

class ExecutionResponse(BaseModel):
    output: str
    error: str

class ReviewRequest(BaseModel):
    code: str
    task_id: str
    topic_id: str = "default"

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    orchestrator_agent = create_orchestrator_agent()
    mentor_agent = create_mentor_agent()
    manager_agent = create_manager_agent()
    reviewer_agent = create_reviewer_agent()
    executor_agent = create_executor_agent()
    advisor_agent = create_advisor_agent()
    session_service = get_session_service()
    
    memory_bank = MemoryBank()
    logger = AgentLogger()
    
    print("Agents and Services initialized successfully.")
except Exception as e:
    print(f"Error initializing agents: {e}")

@app.get("/")
def read_root():
    return {"message": "CodeResidency Backend is running with Google ADK"}

@app.get("/topics", response_model=list[Topic])
def get_topics():
    topics_dict = memory_bank.get_topics()
    return [Topic(id=k, title=v) for k, v in topics_dict.items()]

@app.post("/topics", response_model=Topic)
def create_topic(title: str):
    topic_id = str(uuid.uuid4())
    memory_bank.add_topic(topic_id, title)
    return Topic(id=topic_id, title=title)

@app.delete("/topics/{topic_id}")
def delete_topic(topic_id: str):
    memory_bank.delete_topic(topic_id)
    return {"message": "Topic deleted"}

@app.get("/history/{topic_id}")
async def get_history(topic_id: str):
    return memory_bank.get_history(topic_id)

@app.post("/tasks/generate", response_model=Task)
async def generate_task(topic_id: str):
    try:
        topics_dict = memory_bank.get_topics()
        topic_title = topics_dict.get(topic_id, "General")
        history = memory_bank.get_history(topic_id)
        
        context_text = f"Topic: {topic_title}\nChat History:\n"
        for msg in history[-10:]:
            context_text += f"{msg['role']}: {msg['content']}\n"
            
        tasks_dict = memory_bank.get_tasks()
        previous_tasks = [Task(**t) for t in tasks_dict.values() if t.get('topic_id') == topic_id]
        
        if previous_tasks:
            context_text += "\nPrevious Tasks:\n"
            for t in previous_tasks:
                context_text += f"- {t.title}: {t.description}\n"
                
        prompt = f"""
        Based on the following learning context, generate a new, unique coding task for the user.
        The task should be relevant to what they have recently discussed or learned.
        Do not repeat previous tasks.
        
        {context_text}
        
        You MUST use the following format exactly for your response:
        Title: [A short, descriptive title for the task]
        Description: [A detailed description of what the user needs to do]
        """
        
        logger.log("Manager", "Input", prompt)
        
        session_id = f"session_{topic_id}"
        try:
            await session_service.create_session(session_id=session_id, app_name="CodeResidency", user_id="user_1")
        except Exception:
            pass
        
        user_message = types.Content(role="user", parts=[types.Part(text=prompt)])
        runner = Runner(agent=manager_agent, session_service=session_service, app_name="CodeResidency")
        
        response_text = ""
        async for chunk in runner.run_async(user_id="user_1", session_id=session_id, new_message=user_message):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text
                        
        logger.log("Manager", "Output", response_text)
                        
        title = "New Task"
        description = response_text
        
        lines = response_text.strip().split('\n')
        for line in lines:
            clean_line = line.strip().replace('*', '')
            if clean_line.startswith("Title:"):
                title = clean_line.replace("Title:", "").strip()
            elif clean_line.startswith("Description:"):
                pass
                
        if title != "New Task":
            description = response_text.replace(f"Title: {title}", "").replace(f"**Title**: {title}", "").replace("Description:", "").replace("**Description**:", "").strip()

        task_id = str(uuid.uuid4())
        new_task = Task(
            id=task_id,
            topic_id=topic_id,
            title=title,
            description=description
        )
        memory_bank.add_task(new_task)
        return new_task
    except Exception as e:
        traceback.print_exc()
        logger.log("Manager", "Error", str(e))
        print(f"Error generating task: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tasks")
def get_tasks(topic_id: str = None):
    tasks_dict = memory_bank.get_tasks()
    all_tasks = [Task(**t) for t in tasks_dict.values()]
    if topic_id:
        return [t for t in all_tasks if t.topic_id == topic_id]
    return all_tasks

@app.put("/tasks/{task_id}", response_model=Task)
def update_task(task_id: str, task_update: Task):
    tasks_dict = memory_bank.get_tasks()
    if task_id in tasks_dict:
        current_task_data = tasks_dict[task_id]
        current_task = Task(**current_task_data)
        
        current_task.status = task_update.status
        current_task.code = task_update.code
        current_task.feedback = task_update.feedback
        
        memory_bank.update_task(current_task)
        return current_task
    raise HTTPException(status_code=404, detail="Task not found")

@app.post("/execute", response_model=ExecutionResponse)
def execute_code(request: ExecutionRequest):
    logger.log("Executor", "Input", request.code)
    if request.language.lower() != "python":
        return ExecutionResponse(output="", error="Only Python is supported for now.")
    
    try:
        output = execute_python_code(request.code)
        logger.log("Executor", "Output", output)
        
        if output.startswith("Error:"):
             return ExecutionResponse(output="", error=output)
        else:
             return ExecutionResponse(output=output, error="")
             
    except Exception as e:
        logger.log("Executor", "Error", str(e))
        return ExecutionResponse(output="", error=str(e))

@app.post("/review", response_model=AgentResponse)
async def review_code(request: ReviewRequest):
    try:
        user_id = "user_1"
        topic_id = request.topic_id
        session_id = f"session_{topic_id}"
        
        tasks_dict = memory_bank.get_tasks()
        task_data = tasks_dict.get(request.task_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="Task not found")
        
        task = Task(**task_data)
            
        prompt = f"""
        Review the following code submission for the task: "{task.title}".
        
        Task Description:
        {task.description}
        
        User Code:
        {request.code}
        
        Provide feedback on correctness, style, and efficiency.
        
        IMPORTANT:
        If the code is correct and solves the task, you MUST include the word 'APPROVED' (in all caps) in your response, preferably in a "Review Status" section.
        If there are errors, use 'CHANGES REQUESTED'.
        """
        
        logger.log("Reviewer", "Input", prompt)
        
        try:
            await session_service.create_session(session_id=session_id, app_name="CodeResidency", user_id=user_id)
        except Exception:
            pass
            
        runner = Runner(agent=reviewer_agent, session_service=session_service, app_name="CodeResidency")
        user_message = types.Content(role="user", parts=[types.Part(text=prompt)])
        
        response_text = ""
        async for chunk in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text
        
        logger.log("Reviewer", "Output", response_text)
        
        return AgentResponse(response=response_text, agent_type="REVIEWER")
        
    except Exception as e:
        traceback.print_exc()
        logger.log("Reviewer", "Error", str(e))
        print(f"Error in review endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat", response_model=AgentResponse)
async def chat_endpoint(request: AgentRequest):
    try:
        user_id = "user_1"
        topic_id = request.topic_id if request.topic_id else "default"
        session_id = f"session_{topic_id}"
        
        topics_dict = memory_bank.get_topics()
        if topic_id not in topics_dict:
            memory_bank.add_topic(topic_id, "Unknown Topic")
            
        memory_bank.add_to_history(topic_id, {"role": "user", "content": request.message})
        logger.log("User", "Input", request.message)
        
        try:
            await session_service.create_session(session_id=session_id, app_name="CodeResidency", user_id=user_id)
        except Exception:
            pass

        orchestrator_runner = Runner(agent=orchestrator_agent, session_service=session_service, app_name="CodeResidency")
        routing_decision = ""
        user_message = types.Content(role="user", parts=[types.Part(text=request.message)])
        
        async for chunk in orchestrator_runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
            if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        routing_decision += part.text
        
        target_agent_name = routing_decision.strip().upper()
        logger.log("Orchestrator", "Decision", target_agent_name)
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
            target_agent = mentor_agent
            target_agent_name = "MENTOR"

        runner = Runner(agent=target_agent, session_service=session_service, app_name="CodeResidency")
        response_text = ""
        
        async for chunk in runner.run_async(user_id=user_id, session_id=session_id, new_message=user_message):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text

        memory_bank.add_to_history(topic_id, {"role": "agent", "content": response_text})
        logger.log(target_agent_name, "Output", response_text)

        return AgentResponse(response=response_text, agent_type=target_agent_name)

    except Exception as e:
        traceback.print_exc()
        logger.log("System", "Error", str(e))
        print(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
