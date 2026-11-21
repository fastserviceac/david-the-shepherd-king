# Working in this project

Godot game about David. About 21,500 lines of GDScript in `scripts/`, data in `data/`, build tools in `tools/`.

## Keep the main session small

Every step re-reads the whole conversation, so anything large that enters the main context is paid for again on every later step. Two earlier sessions grew past 900k tokens this way.

- **Do not view images in the main session.** To check frames, screenshots, sprites or contact sheets, start a subagent with `model: "sonnet"`, give it the file paths and exactly what to judge, and ask for a short verdict (pass or fail, and what is wrong, per file). Only open an image here when the subagent's verdict is unclear and the decision depends on it, and then open one downscaled image, not a batch.
- **Do not poll media jobs in the main session.** For Higgsfield, ElevenLabs and Runway generation, hand the whole job to a subagent with `model: "sonnet"`: it submits, waits, downloads the result into the project and returns only the saved file paths and any failure. Never call the listing tools (`show_generations`, `creative_get_generations`, `creative_list_voices`) here; their results are very large.
- **Batch generation.** Submit all the lines or clips for a scene in one subagent run, not one call per item.
- **Keep command output short.** Pipe long output through `tail` or `grep`, and send ffmpeg and Godot logs to a file in the scratchpad, reading only the lines that matter.
- **Read parts of big files.** `scripts/levels/level_base.gd` is about 2,700 lines; search for the function and read that range.

## Sessions

- One session per task or chapter. When a task is finished and committed, suggest starting a new session for the next one instead of continuing here.
- Routine work (voice lines, re-encoding, data and translation edits) does not need the most capable model; say so if the session is on it.
