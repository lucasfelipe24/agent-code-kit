/**
 * SkillIndex — the kit's skills grouped as the README groups them, one row per
 * skill: `/name` and what it does, the whole row a link to its docs page.
 * Rows are separated by rules, not boxed into cards.
 *
 * Empty state: when the build has no skill data, a sentence and a link to the
 * skills overview instead of an empty grid.
 *
 * <SkillIndex lang="en" groups={siteData.skillGroups.en}
 *   emptyText="The skill list isn't available." allLabel="All skills" />
 */
import Link from 'next/link';

export type SkillGroup = {
  name: string;
  skills: { name: string; description: string }[];
};

type SkillIndexProps = {
  lang: string;
  groups: SkillGroup[];
  emptyText: string;
  allLabel: string;
};

export function SkillIndex({ lang, groups, emptyText, allLabel }: SkillIndexProps) {
  const filled = groups.filter((g) => g.skills.length > 0);
  const overview = `/${lang}/docs/skills/`;

  if (filled.length === 0) {
    return (
      <p className="ack-muted">
        {emptyText} <Link href={overview}>{allLabel}</Link>
      </p>
    );
  }

  return (
    <div className="ack-skills">
      {filled.map((group, i) => (
        <section key={group.name} className="ack-skills__group" aria-labelledby={`skill-group-${i}`}>
          <h3 id={`skill-group-${i}`} className="ack-skills__name">
            {group.name}
          </h3>
          <ul className="ack-skills__list">
            {group.skills.map((skill) => (
              <li key={skill.name}>
                <Link href={`/${lang}/docs/skills/${skill.name}/`} className="ack-skills__row">
                  <code className="ack-skills__cmd">/{skill.name}</code>
                  <span className="ack-skills__desc">{skill.description}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

