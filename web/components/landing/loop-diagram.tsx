/**
 * LoopDiagram — Plan → Confirm → Implement → Verify, and back to Plan.
 *
 * An ordered list (the content is a sequence), drawn as nodes on one track;
 * the return arc is decorative. Each step says whether a rule asks for it or a
 * hook enforces it. Horizontal from 768px, vertical below.
 *
 * <LoopDiagram steps={[{ title: 'Plan', body: '…', enforcedBy: 'rule' }, …]}
 *   enforcedLabels={{ rule: 'Asked by a rule', hook: 'Enforced by a hook' }}
 *   returnLabel="The next task starts at Plan again." />
 */
export type LoopStep = {
  title: string;
  body: string;
  enforcedBy: 'rule' | 'hook';
};

type LoopDiagramProps = {
  steps: LoopStep[];
  enforcedLabels: { rule: string; hook: string };
  returnLabel: string;
};

export function LoopDiagram({ steps, enforcedLabels, returnLabel }: LoopDiagramProps) {
  if (steps.length === 0) return null;

  return (
    <div className="ack-loop">
      {/* role="list": Safari drops list semantics under list-style: none */}
      <ol className="ack-loop__steps" role="list">
        {steps.map((step, i) => (
          <li key={step.title} className="ack-loop__step">
            <span className="ack-loop__node" aria-hidden="true">
              {i + 1}
            </span>
            <h3 className="ack-loop__title">{step.title}</h3>
            <p className="ack-loop__body">{step.body}</p>
            <p className={`ack-loop__by ack-loop__by--${step.enforcedBy}`}>
              {enforcedLabels[step.enforcedBy]}
            </p>
          </li>
        ))}
      </ol>
      <p className="ack-loop__return">
        <svg className="ack-loop__arc" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4" fill="none" strokeWidth="2" />
        </svg>
        {returnLabel}
      </p>
    </div>
  );
}
