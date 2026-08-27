# LangGraph Application Publishing Plan

- **Goal**
  - Prepare a simple tutorial for publishing a LangGraph application with a separate frontend.
  - Keep the number of commands and prompts as low as possible.
  - Keep the codebase small and approachable for students.
  - Use CLI utilities and agent skills so Claude can handle as much of the implementation and deployment work as possible.

- **Overall architecture**
  - Use a monorepo.
  - `apps/api`
    - FastAPI backend.
    - LangGraph application.
    - Stateless per request.
    - Expose:
      - Health check endpoint.
      - `/chat` endpoint.
    - Read keys and configuration from environment variables.
    - Containerize the backend.
    - Deploy to Google Cloud Run.
  - `apps/web`
    - Next.js / React frontend.
    - Deploy to Vercel.
    - Keep the client small.
    - Call the backend through an environment-configured API URL.
    - Optionally use a single Next.js API route to forward requests to Cloud Run.

- **CLI-driven workflow**
  - Start from a blank GitHub repository.
  - Install and use:
    - Vercel CLI
    - `gcloud`
  - Add Google Cloud skills / plugin support for Claude Code.
  - Use the available framework and platform skills so Claude can interact directly with deployment platforms.

- **Repository issue as the specification**
  - Create a GitHub issue containing the full assignment.
  - The issue should specify:
    - Monorepo structure.
    - FastAPI + LangGraph backend in `apps/api`.
    - Next.js frontend in `apps/web`.
    - Health check endpoint.
    - `/chat` endpoint.
    - Environment-variable-based configuration.
    - Cloud Run deployment command.
    - Frontend calling the backend through an environment variable.
  - Treat the issue as the main source of truth for the implementation.

- **Claude execution**
  - Launch Claude Code in the repository.
  - Prompt Claude to:
    - Implement the GitHub issue end-to-end.
    - Use the installed CLI utilities and skills.
    - Handle platform-specific deployment work through those tools.
    - Commit the finished implementation.

- **Deployment**
  - Backend:
    - Build and deploy the FastAPI + LangGraph service to Cloud Run.
    - Keep secrets and keys in Cloud Run environment variables.
  - Frontend:
    - Deploy the Next.js app to Vercel.
    - Keep frontend configuration and secrets in Vercel environment variables.

- **Tutorial shape**
  - Focus the tutorial on the agentic deployment pattern:
    - Collect the required keys.
    - Create the blank repository.
    - Write the GitHub issue as a crisp specification.
    - Launch Claude Code with a small number of prompts.
    - Let Claude use the installed CLIs and skills to implement and deploy.
  - Keep the visible manual workflow minimal.
