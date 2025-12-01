import json
import os
from typing import Dict, List, Any
from models import Task, Topic

class MemoryBank:
    def __init__(self, storage_path: str = "data/storage.json"):
        self.storage_path = storage_path
        self.topics: Dict[str, str] = {}
        self.history: Dict[str, List[Dict[str, str]]] = {}
        self.tasks: Dict[str, Dict[str, Any]] = {} # Store as dict for JSON serialization
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(self.storage_path), exist_ok=True)
        self.load()

    def load(self):
        if os.path.exists(self.storage_path):
            try:
                with open(self.storage_path, 'r') as f:
                    data = json.load(f)
                    self.topics = data.get("topics", {})
                    self.history = data.get("history", {})
                    self.tasks = data.get("tasks", {})
            except Exception as e:
                print(f"Error loading memory bank: {e}")
                # Initialize empty if error
                self.topics = {}
                self.history = {}
                self.tasks = {}
        else:
            # Initialize defaults
            self.topics = {"default": "General Chat"}
            self.history = {}
            self.tasks = {}
            self.save()

    def save(self):
        try:
            data = {
                "topics": self.topics,
                "history": self.history,
                "tasks": self.tasks
            }
            with open(self.storage_path, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"Error saving memory bank: {e}")

    # Helper methods to mimic the previous dict interface or provide better access
    
    def get_topics(self) -> Dict[str, str]:
        return self.topics

    def add_topic(self, topic_id: str, title: str):
        self.topics[topic_id] = title
        self.save()

    def delete_topic(self, topic_id: str):
        if topic_id in self.topics:
            del self.topics[topic_id]
        if topic_id in self.history:
            del self.history[topic_id]
        self.save()

    def get_history(self, topic_id: str) -> List[Dict[str, str]]:
        return self.history.get(topic_id, [])

    def add_to_history(self, topic_id: str, message: Dict[str, str]):
        if topic_id not in self.history:
            self.history[topic_id] = []
        self.history[topic_id].append(message)
        self.save()

    def get_tasks(self) -> Dict[str, Any]:
        return self.tasks

    def add_task(self, task: Task):
        # Convert Pydantic model to dict
        self.tasks[task.id] = task.dict()
        self.save()
        
    def update_task(self, task: Task):
        self.tasks[task.id] = task.dict()
        self.save()
        
    def get_task(self, task_id: str) -> Dict[str, Any]:
        return self.tasks.get(task_id)
