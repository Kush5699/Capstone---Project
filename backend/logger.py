import json
import os
import datetime
from typing import Any

class AgentLogger:
    def __init__(self, log_path: str = "logs/agent_trace.jsonl"):
        self.log_path = log_path
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True)

    def log(self, agent_name: str, event_type: str, details: Any):
        """
        Log an event to the JSONL file.
        
        Args:
            agent_name: Name of the agent (e.g., "Orchestrator", "Mentor")
            event_type: Type of event (e.g., "Input", "Output", "ToolCall", "Error")
            details: The content or details of the event (str or dict)
        """
        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "agent": agent_name,
            "type": event_type,
            "details": details
        }
        
        try:
            with open(self.log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps(entry) + "\n")
        except Exception as e:
            print(f"Error writing to agent log: {e}")
