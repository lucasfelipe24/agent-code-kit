'use client';
/**
 * CommandBox — a shell command with a copy button.
 *
 * States: idle → "Copy"; copied → "Copied" for 2s; failed (no clipboard access,
 * e.g. an insecure context) → tells the reader to select the text instead.
 * The status is announced through a polite live region. Long commands scroll
 * horizontally rather than wrap, so what you paste is what you see.
 *
 * <CommandBox command="npx @lucasfelipe23/agent-code-kit init"
 *   labels={{ copy: 'Copy', copied: 'Copied', failed: 'Select the command to copy it' }} />
 */
import { useEffect, useRef, useState } from 'react';
import { cn } from '@/lib/cn';

type CopyLabels = { copy: string; copied: string; failed: string };

type CommandBoxProps = {
  command: string;
  labels: CopyLabels;
  className?: string;
};

type CopyState = 'idle' | 'copied' | 'failed';

export function CommandBox({ command, labels, className }: CommandBoxProps) {
  const [state, setState] = useState<CopyState>('idle');
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);

  async function copy() {
    clearTimeout(timer.current);
    try {
      await navigator.clipboard.writeText(command);
      setState('copied');
    } catch {
      setState('failed');
    }
    timer.current = setTimeout(() => setState('idle'), 2000);
  }

  return (
    <div className={cn('ack-command', className)}>
      {/* focusable so a keyboard can scroll a long command (Safari won't on its own) */}
      <pre className="ack-command__text" tabIndex={0} aria-label={command}>
        <code>{command}</code>
      </pre>
      <button
        type="button"
        className="ack-command__button"
        onClick={copy}
        aria-label={`${labels.copy}: ${command}`}
      >
        {state === 'copied' ? labels.copied : labels.copy}
      </button>
      <span className="ack-command__status" role="status" aria-live="polite">
        {state === 'copied' ? labels.copied : state === 'failed' ? labels.failed : ''}
      </span>
    </div>
  );
}
