import Link from 'next/link';
import type { Metadata } from 'next';
import { Tab, Tabs } from 'fumadocs-ui/components/tabs';
import { CommandBox } from '@/components/landing/command-box';
import { LoopDiagram } from '@/components/landing/loop-diagram';
import { SessionTranscript } from '@/components/landing/session-transcript';
import { SkillIndex } from '@/components/landing/skill-index';
import { isLocale } from '@/lib/i18n';
import { landingCopy } from '@/lib/landing-copy';
import { curlCommand, npxCommand, repoUrl } from '@/lib/shared';
// Written by scripts/gen-skill-docs.sh at build time (prebuild): counts and
// skill groups come from the kit's sources, never from this file.
import siteData from '@/content/site-data.json';

export async function generateMetadata(props: PageProps<'/[lang]'>): Promise<Metadata> {
  const { lang } = await props.params;
  const copy = landingCopy[isLocale(lang) ? lang : 'en'];
  return { title: { absolute: 'agent-code-kit' }, description: copy.lead };
}

export default async function HomePage(props: PageProps<'/[lang]'>) {
  const { lang } = await props.params;
  const locale = isLocale(lang) ? lang : 'en';
  const copy = landingCopy[locale];

  return (
    <div className="ack-landing">
      <section className="ack-hero" aria-labelledby="hero-title">
        <div className="ack-hero__copy">
          <h1 id="hero-title" className="ack-display">
            {copy.title}
          </h1>
          <p className="ack-lead">{copy.lead}</p>
          <CommandBox command={npxCommand} labels={copy.copy} />
          <Link href={`/${locale}/docs/`} className="ack-button">
            {copy.readDocs}
          </Link>
        </div>
        <SessionTranscript label={copy.transcriptLabel} lines={copy.transcript} speakers={copy.speakers} />
      </section>

      <section className="ack-section" aria-labelledby="loop-title">
        <h2 id="loop-title" className="ack-h2">
          {copy.loopHeading}
        </h2>
        <p className="ack-lead">{copy.loopLead}</p>
        <LoopDiagram steps={copy.loop} enforcedLabels={copy.enforcedBy} returnLabel={copy.loopReturn} />
        <p className="ack-counts">{copy.counts(siteData.counts)}</p>
      </section>

      <section className="ack-section" aria-labelledby="skills-title">
        <h2 id="skills-title" className="ack-h2">
          {copy.skillsHeading}
        </h2>
        <p className="ack-lead">{copy.skillsLead}</p>
        <SkillIndex
          lang={locale}
          groups={siteData.skillGroups[locale]}
          emptyText={copy.skillsEmpty}
          allLabel={copy.allSkills}
        />
      </section>

      <section className="ack-section" aria-labelledby="templates-title">
        <h2 id="templates-title" className="ack-h2">
          {copy.templatesHeading}
        </h2>
        <p className="ack-lead">{copy.templatesLead}</p>
        <ul className="ack-templates">
          {siteData.templates.map((name) => (
            <li key={name}>
              <a href={`${repoUrl}/tree/main/examples/${name}`}>
                <code>{name}</code>
              </a>
            </li>
          ))}
        </ul>
      </section>

      <section className="ack-section ack-install" aria-labelledby="install-title">
        <h2 id="install-title" className="ack-h2">
          {copy.installHeading}
        </h2>
        <p className="ack-lead">{copy.installLead}</p>
        <Tabs items={[copy.installNpx, copy.installCurl]} className="ack-install__tabs">
          <Tab value={copy.installNpx}>
            <CommandBox command={npxCommand} labels={copy.copy} />
          </Tab>
          <Tab value={copy.installCurl}>
            <CommandBox command={curlCommand} labels={copy.copy} />
          </Tab>
        </Tabs>
      </section>

      <footer className="ack-footer">
        <p>
          agent-code-kit v{siteData.version}. {copy.footer}{' '}
          <a href={repoUrl}>GitHub</a>
        </p>
      </footer>
    </div>
  );
}
