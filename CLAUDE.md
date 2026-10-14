# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A single-file demo: a Kanban-style IT PMO project board for a fictitious bank, all in `index.html` (markup, `<style>`, `<script>`). There is no build, lint, or test tooling and no package manager. Run it by opening `index.html` in a browser (double-click; no server needed).

## Hard constraints (from the original spec)

- Vanilla HTML/CSS/JS only: no frameworks, bundler, npm, CDN scripts, web fonts, or image files. Use system fonts and inline SVG/Unicode for icons.
- No persistence of any kind: no localStorage, sessionStorage, IndexedDB, or cookies. A refresh resets the board to seeded data, and the UI says so.
- The only backend is FormSubmit's AJAX endpoint (`FORMSUBMIT_ENDPOINT`, config constant at the top of the script). The user's email address must go nowhere else.
- Use a neutral "IT PMO" text wordmark and a blue palette. Don't use real bank logos or trademarks.
- No `!important`, no native `alert()`/`confirm()`. Validation errors are inline and delete confirmation is an inline "Delete? Yes / No".

## Architecture

- `state = { tasks: [], filters: {} }` is the single source of truth. Every change mutates `state` and then calls `renderBoard()`, which re-renders all columns and the header summary via `innerHTML`. Do not mutate card DOM directly.
- Every user-supplied string must go through `escapeHtml()` before it is placed in an HTML string.
- Board events use delegation on `#board` (click, change, and the native drag events), so they survive re-renders. UI-only state that must survive a re-render, such as `confirmingId` (the card showing the delete confirm) and `draggingId`, lives in module-level variables.
- Add Task flow: `handleSubmit` runs `validate()`, then `addTask()` (optimistic: the card appears at once), then `notifyNewTask()` (FormSubmit) inside try/catch. A failed call only shows a warning toast and must never break the board.
- Task IDs are `UOB-ITPM-####` from an in-memory counter (`nextId()`). Seed tasks use dates relative to today, so some are always overdue.
- A task is overdue when `dueDate < today` and its status is not Done.
