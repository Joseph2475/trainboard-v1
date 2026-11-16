# Process log

How I built TrainBoard with AI. Each entry is a real moment from the build: what I asked for, what the AI came back with, and what I decided. Where I disagreed with it, the entry says so.

Tools: Claude Code (Opus) in the terminal for code, API checks and repo setup.

## The problem

Two things kept annoying me.

**Meeting a friend off a train.** To see when a friend's train gets to my local station, I have to open Trainline, work out the route they've taken and which train they got on, then go through the arrival times stop by stop to find when it reaches my station. It's guesswork.

**Station screens only show the next two trains.** I often work on my laptop at a station or in a coffee shop nearby, where there's no departure screen at all, and the screens that do exist only show the next two trains. I want to see the next five, and know straight away if anything changes.

I'd already had a departure widget on my desktop for a while. It works, but it doesn't solve either of these, so I rebuilt it from scratch around them.

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
