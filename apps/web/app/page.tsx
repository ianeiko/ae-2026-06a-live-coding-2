"use client";

import { useState } from "react";

type Message = { role: "user" | "assistant"; content: string };

const API_URL = process.env.NEXT_PUBLIC_API_URL;

export default function Home() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send() {
    const text = input.trim();
    if (!text || pending) return;

    const history: Message[] = [...messages, { role: "user", content: text }];
    setMessages(history);
    setInput("");
    setError(null);
    setPending(true);

    try {
      const res = await fetch(`${API_URL}/chat`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ messages: history }),
      });
      if (!res.ok) throw new Error(`${res.status} ${await res.text()}`);
      const data: { reply: string } = await res.json();
      setMessages([...history, { role: "assistant", content: data.reply }]);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-4 p-6">
      <h1 className="text-lg font-semibold">LangGraph chat</h1>

      <div className="flex flex-1 flex-col gap-3">
        {messages.map((m, i) => (
          <div
            key={i}
            className={
              m.role === "user"
                ? "self-end rounded-lg bg-blue-600 px-3 py-2 text-white"
                : "self-start rounded-lg bg-zinc-200 px-3 py-2 dark:bg-zinc-800"
            }
          >
            {m.content}
          </div>
        ))}
        {pending && <div className="self-start text-sm opacity-60">Thinking…</div>}
        {error && (
          <div className="self-start text-sm text-red-600 dark:text-red-400">
            {error}
          </div>
        )}
      </div>

      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          send();
        }}
      >
        <input
          className="flex-1 rounded-lg border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-900"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Say something"
          aria-label="Message"
        />
        <button
          className="rounded-lg bg-blue-600 px-4 py-2 text-white disabled:opacity-50"
          type="submit"
          disabled={pending || !input.trim()}
        >
          {pending ? "Sending…" : "Send"}
        </button>
      </form>
    </main>
  );
}
