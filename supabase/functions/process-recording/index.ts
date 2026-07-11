import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ────────────────────────────────────────────────────────────────────

interface ProcessPayload {
  recording_id: string;
}

interface NoteSection {
  heading: string;
  bullets: string[];
}

interface ExtractedTask {
  title: string;
  priority: "none" | "low" | "medium" | "high" | "urgent";
  deadline: string | null; // ISO date string or null
}

interface StructuredOutput {
  title: string;
  summary: string;
  sections: NoteSection[];
  tasks: ExtractedTask[];
}

// ─── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const groqKey = Deno.env.get("GROQ_API_KEY")!;

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  let payload: ProcessPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { recording_id } = payload;
  if (!recording_id) {
    return new Response(JSON.stringify({ error: "recording_id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── 1. Fetch the recording row ──────────────────────────────────────────────
  const { data: recording, error: fetchErr } = await supabase
    .from("recordings")
    .select("*")
    .eq("id", recording_id)
    .single();

  if (fetchErr || !recording) {
    return new Response(
      JSON.stringify({ error: "Recording not found", detail: fetchErr?.message }),
      { status: 404, headers: { "Content-Type": "application/json" } }
    );
  }

  // Helper: mark recording as errored
  const markError = async (msg: string) => {
    await supabase
      .from("recordings")
      .update({ status: "error", error_message: msg })
      .eq("id", recording_id);
  };

  try {
    // ── 2. Mark as transcribing ────────────────────────────────────────────────
    await supabase
      .from("recordings")
      .update({ status: "transcribing" })
      .eq("id", recording_id);

    // ── 3. Download audio from Storage ────────────────────────────────────────
    const { data: fileData, error: dlErr } = await supabase.storage
      .from("audio")
      .download(recording.storage_path);

    if (dlErr || !fileData) {
      await markError(`Storage download failed: ${dlErr?.message}`);
      return new Response(
        JSON.stringify({ error: "Storage download failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 4. Transcribe via Groq Whisper (free tier) ────────────────────────────
    const ext = recording.storage_path.endsWith(".webm") ? "webm" : "m4a";
    const mimeType = ext === "webm" ? "audio/webm" : "audio/mp4";
    const audioFile = new File([fileData], `audio.${ext}`, { type: mimeType });

    const whisperForm = new FormData();
    whisperForm.append("file", audioFile);
    whisperForm.append("model", "whisper-large-v3-turbo");
    whisperForm.append("response_format", "text");

    const whisperRes = await fetch(
      "https://api.groq.com/openai/v1/audio/transcriptions",
      {
        method: "POST",
        headers: { Authorization: `Bearer ${groqKey}` },
        body: whisperForm,
      }
    );

    if (!whisperRes.ok) {
      const detail = await whisperRes.text();
      await markError(`Transcription failed: ${detail}`);
      return new Response(
        JSON.stringify({ error: "Transcription failed", detail }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const rawTranscript = (await whisperRes.text()).trim();

    // ── 5. Save transcript ─────────────────────────────────────────────────────
    const { data: transcriptRow, error: transcriptErr } = await supabase
      .from("transcripts")
      .insert({
        recording_id,
        user_id: recording.user_id,
        body: rawTranscript,
      })
      .select()
      .single();

    if (transcriptErr) {
      await markError(`Transcript insert failed: ${transcriptErr.message}`);
      return new Response(
        JSON.stringify({ error: "Transcript save failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Mark as transcribed
    await supabase
      .from("recordings")
      .update({ status: "transcribed" })
      .eq("id", recording_id);

    // ── 6. Structure via Groq / Llama 3.3 70B ─────────────────────────────────
    await supabase
      .from("recordings")
      .update({ status: "processing" })
      .eq("id", recording_id);

    const today = new Date().toISOString().split("T")[0];

    const systemPrompt = `You are a world-class note-taking assistant. You transform raw voice transcripts into structured notes and extract actionable tasks.

Today's date is ${today}.

You MUST respond with valid JSON only — no markdown, no explanation, no code fences. The JSON must exactly match this schema:
{
  "title": "string — concise title for the note (max 60 chars)",
  "summary": "string — 1-2 sentence summary of the main points",
  "sections": [
    {
      "heading": "string — section heading",
      "bullets": ["string", "string"]
    }
  ],
  "tasks": [
    {
      "title": "string — clear, actionable task title",
      "priority": "none | low | medium | high | urgent",
      "deadline": "YYYY-MM-DD or null"
    }
  ]
}

Rules:
- Organize sections logically by topic, not chronologically
- Each section has 2-6 bullets
- Extract both explicit tasks ("I need to...") and implied tasks (deadlines mentioned, things that clearly need to happen)
- Set priority based on urgency language in the transcript
- Set deadline only when a specific date/time is mentioned or clearly implied
- If there are no tasks, return an empty tasks array
- Return at least 1 section even for short transcripts`;

    const groqRes = await fetch(
      "https://api.groq.com/openai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${groqKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "llama-3.3-70b-versatile",
          messages: [
            { role: "system", content: systemPrompt },
            {
              role: "user",
              content: `Please structure this voice transcript:\n\n${rawTranscript}`,
            },
          ],
          temperature: 0.3,
          max_tokens: 2048,
          response_format: { type: "json_object" },
        }),
      }
    );

    if (!groqRes.ok) {
      const detail = await groqRes.text();
      await markError(`Groq failed: ${detail}`);
      return new Response(
        JSON.stringify({ error: "Structuring failed", detail }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const groqJson = await groqRes.json();
    const rawContent = groqJson.choices?.[0]?.message?.content ?? "{}";

    let structured: StructuredOutput;
    try {
      structured = JSON.parse(rawContent) as StructuredOutput;
    } catch {
      await markError("Groq returned invalid JSON");
      return new Response(
        JSON.stringify({ error: "Invalid structured output from LLM" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 7. Save note ───────────────────────────────────────────────────────────
    const { data: noteRow, error: noteErr } = await supabase
      .from("notes")
      .insert({
        recording_id,
        user_id: recording.user_id,
        project_id: recording.project_id ?? null,
        title: structured.title ?? "Untitled Note",
        summary: structured.summary ?? "",
        sections: structured.sections ?? [],
      })
      .select()
      .single();

    if (noteErr) {
      await markError(`Note insert failed: ${noteErr.message}`);
      return new Response(
        JSON.stringify({ error: "Note save failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // ── 8. Save tasks ──────────────────────────────────────────────────────────
    if (structured.tasks && structured.tasks.length > 0) {
      // Get current max sort_order for this user so new tasks land at bottom
      const { data: maxRow } = await supabase
        .from("tasks")
        .select("sort_order")
        .eq("user_id", recording.user_id)
        .order("sort_order", { ascending: false })
        .limit(1)
        .single();

      const baseOrder = (maxRow?.sort_order ?? 0) + 1;

      const taskInserts = structured.tasks.map((t, i) => ({
        user_id: recording.user_id,
        project_id: recording.project_id ?? null,
        source_note_id: noteRow.id,
        title: t.title,
        priority: t.priority ?? "none",
        deadline: t.deadline ?? null,
        completed: false,
        sort_order: baseOrder + i,
      }));

      const { error: tasksErr } = await supabase
        .from("tasks")
        .insert(taskInserts);

      if (tasksErr) {
        // Non-fatal — note is saved, log error but continue
        console.error("Tasks insert error:", tasksErr.message);
      }
    }

    // ── 9. Mark recording done ─────────────────────────────────────────────────
    await supabase
      .from("recordings")
      .update({ status: "done" })
      .eq("id", recording_id);

    return new Response(
      JSON.stringify({
        success: true,
        recording_id,
        note_id: noteRow.id,
        transcript_length: rawTranscript.length,
        tasks_extracted: structured.tasks?.length ?? 0,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await markError(`Unexpected error: ${msg}`);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: msg }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
