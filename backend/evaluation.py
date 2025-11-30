import asyncio
import os
from dotenv import load_dotenv
from google.adk import Runner
from google.adk.sessions import InMemorySessionService
import google.genai.types as types

# Import agent creators
from agents.orchestrator import create_orchestrator_agent
from agents.mentor import create_mentor_agent
from agents.executor import create_executor_agent

# Load env
load_dotenv()

async def run_evaluation():
    print("Starting Agent Evaluation...\n")
    
    session_service = InMemorySessionService()
    
    # 1. Test Orchestrator Routing
    print("--- Test Case 1: Orchestrator Routing ---")
    orchestrator = create_orchestrator_agent()
    orch_runner = Runner(agent=orchestrator, session_service=session_service, app_name="Eval")
    
    await session_service.create_session(session_id="test_session", app_name="Eval", user_id="test_user")
    
    test_inputs = [
        ("How do I define a function in Python?", "MENTOR"),
        ("Please run this code for me.", "EXECUTOR"),
        ("Give me a new coding task.", "MANAGER"),
        ("Review my code please.", "REVIEWER")
    ]
    
    score = 0
    for user_text, expected_agent in test_inputs:
        print(f"Input: '{user_text}'")
        response_text = ""
        user_msg = types.Content(role="user", parts=[types.Part(text=user_text)])
        
        async for chunk in orch_runner.run_async(user_id="test_user", session_id="test_session", new_message=user_msg):
             if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
                for part in chunk.content.parts:
                    if part.text:
                        response_text += part.text
        
        result = response_text.strip().upper()
        if expected_agent in result:
            print(f"Passed (Routed to {result})")
            score += 1
        else:
            print(f"Failed (Expected {expected_agent}, got {result})")
            
    print(f"Orchestrator Score: {score}/{len(test_inputs)}\n")

    # 2. Test Executor Tool
    print("--- Test Case 2: Executor Tool Usage ---")
    executor = create_executor_agent()
    exec_runner = Runner(agent=executor, session_service=session_service, app_name="Eval")
    
    await session_service.create_session(session_id="test_session_exec", app_name="Eval", user_id="test_user")
    
    code_input = "print(5 + 10)"
    user_text = f"Execute this code: {code_input}"
    print(f"Input: '{user_text}'")
    
    response_text = ""
    user_msg = types.Content(role="user", parts=[types.Part(text=user_text)])
    
    # Note: The Runner should handle tool calls automatically if the agent is configured correctly.
    async for chunk in exec_runner.run_async(user_id="test_user", session_id="test_session_exec", new_message=user_msg):
         if hasattr(chunk, 'content') and chunk.content and chunk.content.parts:
            for part in chunk.content.parts:
                if part.text:
                    response_text += part.text
                    
    print(f"Output: {response_text.strip()}")
    
    if "15" in response_text:
        print("Passed (Code executed correctly)")
    else:
        print("Failed (Did not find expected output '15')")
        
    print("\nEvaluation Complete.")

if __name__ == "__main__":
    asyncio.run(run_evaluation())
