# Process log

How I built TrainBoard with AI. Each entry is a real moment from the build: what I asked for, what the AI came back with, and what I decided. Where I disagreed with it, the entry says so.

Tools: Claude Code (Opus) in the terminal for code, API checks and repo setup.

## The problem

I check my phone several times a day to see when trains at Fratton leave, and more often when a friend is coming down from London and I want to know when to meet them. I've had a departure widget on my desktop for a while; it works, but finding one specific train on it is still guesswork. I wanted to rebuild it from scratch, with a better experience and a clear answer to "when does my friend's train get in?"

## Log

### 1. Picking the lens
- **Asked:** read the brief and suggest projects.
- **AI:** suggested a few options from my own work, mostly data-heavy "make it click" ideas.
- **Decided:** I went with Lens A, a working tool, because this is a daily annoyance I actually have.

### 2. Rebuild, not reuse
- **AI:** suggested renaming and archiving the old widget's repo and keeping it public.
- **Pushed back:** I wanted a clean start, so I made the old repo private and started fresh. Every line in this repo is written for this build.

### 3. Time limit
- **AI:** suggested starting a strict 3 hour clock at the first line of code.
- **Pushed back:** I kept it loose and put the time into getting the experience right.

### 4. Checking the friend's train idea is possible
- **Asked:** can the board find a friend's train, like the 12:50 London to Fratton?
- **AI:** tested the traini.ac API live. The journey lookup (`/v1/journey/WAT/FTN`) returns a train id for each service, and the same id can be matched on the Fratton board, so the widget can highlight that train.
- **Decided:** build around that match.
