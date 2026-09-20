# Study Space

## Overview

Study Space is an open-source learning platform for creating, organizing, and delivering interactive courses. It combines course management, rich learning activities, AI assistance, collaboration tools, and mathematical content rendering in one workspace.

## Problem Statement

Learning content is often split across documents, video platforms, chat tools, coding environments, and separate assessment systems. This makes it difficult for learners to stay focused and for educators to manage a coherent learning experience.

## Solution

Study Space brings course content, activities, assessments, AI-powered assistance, and collaborative workspaces together in a single platform. The chatbot can use course content and the currently opened activity as context, while MathJax renders mathematical notation consistently across learning pages and chat responses.

## Features

* Course and organization management
* Interactive activities, assignments, quizzes, Markdown, and coding playgrounds
* AI chatbot grounded in course content and the currently opened activity
* OpenAI integration with configurable low-cost models
* MathJax support across course content, previews, coding playground descriptions, and chatbot responses
* Real-time collaborative editing with WebSocket support
* Progress tracking, certifications, communities, and learning trails
* Responsive dashboard and learner experience

## Tech Stack

* *Frontend:* Next.js, React, TypeScript, Tailwind CSS
* *Backend:* FastAPI, Python, Uvicorn
* *Database:* PostgreSQL with pgvector
* *APIs / Services:* OpenAI API, Redis, MathJax, Hocuspocus collaboration server
* *Hosting / Deployment:* Docker-compatible deployments and local native development
* *Other Tools:* Bun, uv, Tiptap, ProseMirror, React Query, Sentry

## Codex / OpenAI Usage

OpenAI Codex and ChatGPT were used throughout the hackathon for:

* Ideation and architecture planning
* Code generation and feature implementation
* Debugging local development and service startup issues
* Integrating OpenAI models and selecting cost-conscious model defaults
* Adding MathJax support to Markdown and chatbot renderers
* Improving local development performance
* Testing API, frontend, and service connectivity
* Preparing documentation and the local development launcher

AI helped accelerate the implementation of the learning experience, diagnose integration issues, and connect the frontend chatbot to relevant course and activity context.

## How to Run Locally

Requirements:

* Node.js 20 or newer
* Bun
* Python 3.14.7 and uv
* Docker, for PostgreSQL and Redis
* An OpenAI API key for AI features

Create `apps/api/.env` with your OpenAI key:

```env
LEARNHOUSE_AI_API_KEY=your_openai_api_key
```

Start the complete local stack:

```bash
git clone <repo-url>
cd <project-folder>
bun install --cwd apps/web
bun install --cwd apps/collab
./scripts/run_dev.sh
```

The launcher starts PostgreSQL, Redis, the FastAPI backend, the collaboration server, and the Next.js frontend.

Local URLs:

* Web: `http://localhost:3000`
* API: `http://localhost:1338`
* Collaboration server: `ws://localhost:4000`

## Additional Notes

* AI features require a valid OpenAI API key and available account credits.
* The local launcher stores generated development secrets in the ignored `.dev-secrets` file.
* Development logs are written to `/tmp/study-space-dev`.
* MathJax is loaded on demand in the browser, so mathematical content requires network access to the MathJax CDN unless the loader is changed to a self-hosted build.
* Production deployment should use managed secrets, persistent PostgreSQL and Redis storage, and a proper domain configuration.
