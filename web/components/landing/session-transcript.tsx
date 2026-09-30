/**
 * SessionTranscript — the hero's replay of a Claude Code session.
 *
 * Lines appear once, in order (CSS only; --i drives each delay), and the page's
 * one loud element — the hook's BLOCKED output — arrives last. With
 * prefers-reduced-motion the final state renders at once. The whole text is in
 * the DOM from the start, so the animation is decorative for screen readers,
 * and each line names its speaker for them (the colors carry it visually).
 *
 * <SessionTranscript label="A session where a hook blocks…" lines={[
 *   { kind: 'user', text: 'Add a search feature' },
 *   { kind: 'block', text: 'BLOCKED by protect-changes.sh: …' },
 * ]} />
 */
export type TranscriptLine = {
  kind: 'user' | 'agent' | 'tool' | 'block';
  text: string;
  /** Set when the line's language differs from the page's (tool output stays English). */
  lang?: string;
};

type SessionTranscriptProps = {
  label: string;
  lines: TranscriptLine[];
  /** Screen-reader-only speaker per line kind, e.g. { user: 'You:' }. */
  speakers: Record<TranscriptLine['kind'], string>;
};

const prefix: Record<TranscriptLine['kind'], string> = {
  user: '›',
  agent: '',
  tool: '',
  block: '',
};

export function SessionTranscript({ label, lines, speakers }: SessionTranscriptProps) {
  if (lines.length === 0) return null;

  return (
    <figure className="ack-transcript">
      <figcaption className="sr-only">{label}</figcaption>
      <div className="ack-transcript__bar" aria-hidden="true">
        <span>claude</span>
      </div>
      {/* role="list": Safari drops list semantics under list-style: none */}
      <ol className="ack-transcript__lines" role="list">
        {lines.map((line, i) => (
          <li
            key={i}
            className={`ack-transcript__line ack-transcript__line--${line.kind}`}
            style={{ '--i': i } as React.CSSProperties}
          >
            {prefix[line.kind] && (
              <span className="ack-transcript__prefix" aria-hidden="true">
                {prefix[line.kind]}
              </span>
            )}
            <span className="sr-only">{speakers[line.kind]} </span>
            <span lang={line.lang}>{line.text}</span>
          </li>
        ))}
      </ol>
    </figure>
  );
}
