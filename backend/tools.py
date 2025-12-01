import subprocess
import sys
import traceback

def execute_python_code(code: str) -> str:
    """
    Executes the given Python code and returns the output (stdout) or error (stderr).
    This is a sandboxed execution (simulated via subprocess for this project).
    """
    try:
        if "import os" in code or "import subprocess" in code:
             pass

        result = subprocess.run(
            [sys.executable, "-c", code],
            capture_output=True,
            text=True,
            timeout=10  # 10 seconds timeout
        )
        
        output = result.stdout
        if result.stderr:
            output += f"\nError:\n{result.stderr}"
            
        return output.strip()
    except subprocess.TimeoutExpired:
        return "Error: Execution timed out (10s limit)."
    except Exception as e:
        return f"Error executing code: {str(e)}"
