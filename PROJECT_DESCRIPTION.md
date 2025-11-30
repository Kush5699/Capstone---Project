# CodeResidency - Project Description

## Problem Statement
Traditional self-paced coding education often feels isolated and theoretical. Learners watch videos and solve isolated algorithmic puzzles, but they rarely experience the dynamics of a real-world software engineering environment. They lack the structured guidance of a manager, the technical mentorship of a senior engineer, and the rigorous feedback of a code review process. This gap between learning and doing leaves many aspiring developers unprepared for the collaborative and complex nature of professional software development, leading to "tutorial hell" and a lack of confidence in building real applications.

## Solution Statement
CodeResidency bridges this gap by creating an immersive, agent-powered workplace simulation. It transforms the solitary learning process into an interactive job simulation where users work alongside a team of AI agents. A **Manager Agent** assigns realistic tasks based on the user's skill level, a **Mentor Agent** provides guidance and answers technical questions, and a **Reviewer Agent** offers professional-grade code reviews. Crucially, an **Executor Agent** runs the user's code in a secure environment, providing immediate feedback. This ecosystem allows users to experience the entire software development lifecycle—from task assignment to implementation, testing, and review—within a safe, supportive, and intelligent environment.

## Architecture
Core to CodeResidency is a sophisticated multi-agent system built using **Google's Agent Development Kit (ADK)**. It is not a simple chatbot but a coordinated ecosystem of specialized agents, each playing a distinct role in the user's development journey. The system is orchestrated by a central router that ensures the user's intent is handled by the most appropriate expert.

The **Orchestrator Agent** acts as the intelligent front-line interface. It analyzes every user interaction—whether it's a question, a code submission, or a request for a new task—and dynamically routes it to the specialized agent best equipped to handle it.

The power of CodeResidency lies in its team of specialized sub-agents:

### Task Manager: `manager_agent`
This agent acts as the user's engineering manager. It maintains the "Project Context" and assigns tasks that are appropriate for the user's current progression. It ensures that work is broken down into manageable chunks and tracks the status of ongoing assignments.

### Technical Mentor: `mentor_agent`
The mentor is an expert senior engineer available 24/7. It answers conceptual questions, explains complex topics, and provides hints without giving away the solution. It uses the project's context to give relevant advice, simulating a helpful colleague at a desk nearby.

### Code Reviewer: `reviewer_agent`
Once a user submits a solution, the reviewer agent takes over. It analyzes the code not just for correctness, but for style, efficiency, and best practices. It provides constructive feedback similar to what one would receive in a professional Pull Request review, fostering good coding habits early on.

### Code Executor: `executor_agent`
This agent is the hands-on runtime environment. It is responsible for safely executing the Python code written by the user. It handles the interface between the chat-based agent system and the actual code execution sandbox, returning standard output and error logs directly to the user.

## Essential Tools and Utilities
The agents are equipped with specialized tools to perform their roles effectively:

### Sandboxed Code Execution (`execute_python_code`)
A critical tool used by the `executor_agent`. It allows the system to take raw Python code strings from the user, execute them in a controlled subprocess environment, and capture the output (stdout) and errors (stderr). This tool ensures that users can run and test their code in real-time within the platform.

### Contextual Memory Store
The system utilizes a shared memory architecture that allows all agents to access the user's session history. This means the Reviewer knows what the Manager assigned, and the Mentor knows what the Executor just ran, creating a seamless and coherent user experience.

## Conclusion
CodeResidency demonstrates the transformative potential of multi-agent systems in education. By leveraging the Google ADK to orchestrate a team of specialized AI agents, we have created a platform that goes beyond static tutorials. It provides a dynamic, responsive, and personalized learning environment that mimics the real world. This approach not only teaches coding skills but also instills the professional workflows and collaborative mindset essential for a successful career in software engineering.

## Value Statement
"CodeResidency accelerated my learning by simulating the pressure and support of a real job. Instead of just writing code that 'works', I learned to write code that is clean, maintainable, and approved by a senior reviewer. The instant feedback from the Executor and the structured tasks from the Manager made me feel like I was actually contributing to a project, not just solving toy problems. It saved me months of trial and error by giving me the mentorship I couldn't afford otherwise."
